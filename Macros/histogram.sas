/*========================================================================  
DataFit Toolkit - Histogram macro
© 2020 Institute for Clinical Evaluative Sciences (ICES).

TERMS OF USE:
 
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

========================================================================*/


/*___________________________________________________________________________
 |  MACRO:       histogram
 |
 |  JOB:         Data Quality
 |
 |  PROGRAMMER:  Xiaoping Zhao
 |
 |  DATE:        May 2013
 |
 |  DESCRIPTION: This Macro is called in VIMO to create histograms for numerical
 |               variables that are: 
 |               - Formatted with either 'BEST', 'Z' or have no formats
 |               - Not specified as ID variables
 |
 |               NOTE: There will be a message in the log about intervals being
 |                     unevenly spaced. This occurs when a variable is discrete
 |                     but there gaps in the sequence of numbers (e.g 1,2,4)
 |
 |               The number of bins is calculated using the following logic:
 |               1. Use the Freedman-Diaconis Rule to get the optimal number of
 |                  bins
 |               2. If the F-D rule yields more than 30 bins, the number of bins
 |                  is capped at 30
 |               3. If there are less than 30 unique values, the discrete option
 |                  is used so that each value gets it's own bin
 |               4. If the F-D rule yields zero bins (such as when Q3-Q1=0, then 
 |                  then no options are used and the bin calculation is left up 
 |                  to SAS
 |
 |  PARAMETERS:  None
 |
 |  UPDATES:     Apr 08, 2014 (Nicholas Gnidziejko)
 |               - Enhanced documentation
 |               - 1 bar per value is used in graph when there are less then
 |                 30 unique values present (discrete option)
 |               - Number of bins is now calculated using Freedman-Diaconis 
 |                 rule, with a max of 30 bins  
 |               - Output graphs are now wider  
 |               - Outliers are no longer exluded in histograms
 |               - Dataset name added to histograms
 |           
 |               May 21, 2014 (Nicholas Gnidziejko)
 |               - Macro no longer tries to create histogram for numeric 
 |                 variables with 100% missing values
 |               - Replaced proc delete with proc datasets to avoid warning
 |                 when work datasets are not created
 |
 |               May 22, 2014 (Nicholas Gnidziejko)
 |               - When the F-D rule determins that the number of bins should
 |                 be zero, the number of bins is instead left to be calculated
 |                 automatically by SAS
 |
 |               May 23, 2014 (Nicholas Gnidziejko)
 |               - Increase width of output graph
 |
 |               Aug 08, 2015 (Nicholas Gnidziejko)
 |               - Add code to solve the issue: when running VIMO multiple times
 |                 in the same session, for the same name variable, no matter it
 |                 exits in different datasets or the same dataset, its histogram 
 |                 graph cannot display in VIMO html file.
 |
 |              Nov 2016, Mahmoud Azimaee
 |              - Major updates on all macros in order to make them compatible with SAS PC  
 |
 |              Dec 2016, Milton Hu
 |              - Add 'missing' option at proc gchart procedure, missing value can be treated as 
 |                one individual bar
 |            
  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%macro histogram;

/*******************************************************************
   Get list of variables to produce histograms for 
*******************************************************************/
PROC SQL NOPRINT;
 SELECT strip(NAME) INTO :histolist SEPARATED by " "
 from &METALIB..metadata
  where libname="&LIB" 
   & memname="&DSN" 
   & lowcase(type)='num' 
   & format in (' ','BEST','Z') 
   & upcase(name) not in (&IDIN)
    order by strip(name);
quit;

/*******************************************************************
   Loop through each variable
   - Determine number of bins
   - Create histogram
*******************************************************************/
%DO h=1 %TO &sqlobs;

 %let var=%lowcase(%scan(&histolist, &h));

 /* Get number of unique values */
 ods output nlevels=levels;

 proc freq data=&lib..&dsn. nlevels;
  tables &var. /noprint;
 run;

 /* Flag variables with 100% missing so that proc gchart is not run on them */
 data _null_;
  set levels;

  if NMissLevels=1 and NLevels=1 then do;
   call symputx("_allmissing",1);
  end;
  else do;
   call symputx("_allmissing",0);
  end;
 run; 

 %if &_allmissing. = 0 %then %do;

 /* Determine if variable should be discrete or not */
 %let discretevar=;
 proc sql noprint;
  select tablevar into :discretevar from levels
   where nlevels <= 30;
 quit;

 /* Calculate Number of bins using Freedman-Diaconis Rule */
 %if %length(&discretevar.) = 0 %then %do;
  
  proc means data=&lib..&dsn. noprint;
   var &var.;
   output out=stats(drop=_:) min=min max=max q1=q1 q3=q3 n=n;
  run; 

  data _null_;
   set stats;

   binsize=2*((q3-q1)/(n**(1/3)));
   
   if binsize > 0 then do;
    numlevels=round((round(max-min))/binsize);
    call symputx('numlevels',numlevels);
   end;
   *set numlevels=0 when binsize=0 so that SAS calculate an optimal binsize instead;
   else do;
    call symputx('numlevels',0);
   end; 
  run;

  /* Cap number of bins at 30 */
  %if &numlevels. > 30 %then %let numlevels=30;

 %end;
 
 /* For use in vimo_html macro */
 %let qhistovars=&qhistovars "&var";

/* Define Output file type */
goptions device=png hsize=14.5in ;

ods graphics on /width=4in;
ods listing close;
ods html
%IF &sysscp^=WIN %THEN %DO; 
	path ="&path./Freq/" (url=none)
    file="&var..html"
%END;
%ELSE %DO;
	path ="&path.\Freq\" (url=none)
	file="&var..html"
%END;
style=statistical;
title1 "Distribution for &var in &dsn";
axis1 color=blue;
axis2 label=(angle=90 'Percent of Records')
      color=blue ;

/* check the catalog exist or not, if it exists then delete the catalog */
%if %sysfunc(cexist(work.&dsn.)) %then
  %do;
    proc catalog c = work.&dsn. kill force;
    run;
    quit;
  %end;

proc gchart data=&lib..&dsn. gout =work.&dsn.;
 vbar &var/type=pct
           name="&var"
           maxis=axis1
           raxis=axis2
           space=0
           outside=percent
		   missing
         %if (%length(&discretevar.) = 0) %then %do;
          %if &numlevels. > 0 %then %do;
           levels=&numlevels range
          %end;
         %end; 
         %else %do;
           discrete
         %end;
         ;
run;
quit;

ods html close;
ods listing;
ods graphics off;
title;
%end;
quit;
%END;

goptions reset=all;

proc datasets library=WORK nolist nowarn;
	delete stats levels;
run; 

%mend histogram;
