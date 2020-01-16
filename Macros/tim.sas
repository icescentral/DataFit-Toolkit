/*========================================================================  
DataFit Toolkit - TIM macro
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

/**********************************************************************
   Macro:      Trends in Missingness (TIM) (previously called-MISSINGVALUES)

   Purpose:    Create report containing the percentage of missing values
               over time for each variable in a data holding
   
   Input:      SAS Dataset(s)
   
   Output:     Excel ready tab-delimited text file called <DATA>_tim.txt
   
   Details:    Yearly Datasets
               - Yearly counts will provided based on the year of the file
               - start and end parameters must be provided

               Cumulative Datasets
               - Yearly counts will be provided based on the year found
                 in the refdate variable
               - start and end parameters do not need to be provided  

               See the TIM intranet page for complete details
               on how to generate a fully formatted missing values report
               
               
   Example 1:  Missing Values Report for posted CIHI data
            
               %tim(
                  library = cihi,
                  data = cihi,
                  start = 1988,
                  end = 2012
                  )
   
   Example 2:  Missing Values Report for CIC, run prior to posting

               %tim(
                  library = cic,
                  data = cic,
                  refdate = landing_date,
                  dir = /deid/dq/cic/topost
                  )
                  
   Contact:     Nicholas Gnidziejko

   Created:     Nov 08, 2013 (Nicholas Gnidziejko)
   
   Updates:     Jan 16, 2014 (Nicholas Gnidziejko)
                - Documentation updates

                Jan 17, 2014 (Nicholas Gnidziejko)
                - start and end parameters can now be used with cummulative
                  datasets

                Jan 31, 2014 (Nicholas Gnidziejko)
                - Removed dependencies on ICES macros and formats

                May 15, 2014 (Nicholas Gnidziejko)
                - Output filename is now <datasetname>_tim.txt
                  to be consistent with other DQ macros
                - Temporarily turn off mprint to hide some unnecessary 
                  information from log 

               June 19, 2014 (Sean Ji)
               - fixed the bug: when the length of &data._tim
                 is geater than 32, using &data_tim as a
                 dataset name will cause an syntax error.
                
               March 17, 2015 (Sean Ji)
               - Comment out the code generating the tabfile
               - Add sub-macro tim_html to generate html
                 format report
               - if the path parameter is not specified, the html 
                 report goes to staging folder

               April 06, 2015 (Sean Ji)
               - fixed the bug that the last alphabetic order variable
                 is not listed in the report

			         April 17,2015 (Gangamma Kalappa)
			         - Renamed the macro from missingvalues to tim

               Nov 2016, Mahmoud Azimaee
               - Major updates on all macros in order to make them compatible with SAS PC  

               Dec 06 2016, Sean Ji
               - Added new parameter TIM to allow %TIM can generate report by calendar year or
                 fiscal year
               - Added code to let the parameter REFDATE can take DATETIME variable 

*************** INSTRUCTIONS ******************************************

You MUST specify:

   library      Library name for the data holding

   data         Name or prefix of name for input SAS dataset(s)
   
                This parameter is specified in two different ways, depending on if
                the data holding is broken down itno yearly datasets or a single
                cummulative dataset.
   
                Yearly Datasets:
                Prefix name of the input SAS datasets. For example, 
                if the library contains files cihi1988.sas7bdat-
                cihi2011.sas7bdat then set data=cihi.

                Cumulative Datasets:
                Name of input SAS dataset
                Example: data=omhrs_admission
   path			Directory to output missing values report to 

You also may specify:

   start        First year of data to report on 
   
                This parameter is specified in two different ways, depending on if
                the data holding is broken down itno yearly datasets or a single
                cummulative dataset.
   
                Yearly Datasets:
                Mandatory, the first year of the data to report on
                Example: start=1988

                Cumulative Datasets:
                N/A
                
   end          Last year of data to report on 
   
                This parameter is specified in two different ways, depending on if
                the data holding is broken down itno yearly datasets or a single
                cummulative dataset.
   
                Yearly Datasets:
                Mandatory, the last year of the data to report on
                Example: end=2012

                Cumulative Datasets:
                N/A
                
   refdate      Name of index date variable
   
                This parameter is specified in two different ways, depending on if
                the data holding is broken down itno yearly datasets or a single
                cummulative dataset.
   
                Yearly Datasets:
                N/A

                Cumulative Datasets:
                The name of the date variable found in the dataset
                that will be used as the index date for the report

   testn        Number of observations to limit input SAS dataset(s) to
   
                For testing purposes, optionally specify a small number for testn to
                limit the number of observations in the input dataset(s) 
                Example: testn=100

   altdir       Alternate directory to read data from
   
                Use this parameter when you would like to use the 
                standard libname but the data is not found in a standard location
                (i.e. data has not yet been posted and still resides in a working
                directory)
                Example: dir=/deid/dq/nacrs/post

   time         Allow generate the TIM report based on calendar year or fiscal year
                Must be one of these values: FISCAL, CALENDAR
                (default value is FISCAL)

**********************************************************************/

%macro tim(
   library = ,
   data = ,
   start = , 
   end =,
   refdate = ,
   file = ,
   altdir = ,
   path = ,
   testn =,
   time  = fiscal
   );

%local dtvarfmt;

/* Uppercase Parameters */
%let library=%upcase(&library.);
%let data=%upcase(&data.);

/* Define output file name */
%if %length(&file.) = 0 %then %do;
 %let file = %lowcase(&data.)_tim.txt;
%end; 

/* Define the output path, if parameter is empty */
%if %sysevalf(%superq(path)=, boolean) %then
    %do;
        %let path = /sasroot/staging/&sysuserid;
    %end;

/* Save current options to restore them later */
proc optsave key="core\options";
run;

/* Turn off warning for merge without by statement */
options mergenoby=nowarn;

/* Testing parameter */
%if %length(&testn.) = 0 %then %do;
 %let n = max;
%end;
%else %do;
 %let n = &testn.;
%end; 

/* Define Cumulative Datasets that should be reported on by fiscal year */
/******************************************************************
***************  Commented Out (06/12/2016) - Sean Ji *************

%let fiscaldata = omhrs_admission;
%let fiscaldata = %upcase(&fiscaldata.);
*********************  End Commenting Out **************************
********************************************************************/


/*******************************************************************
   Libraries
*******************************************************************/
/* Specify if data will be read from work or permanent library */
%if %length(&refdate.) = 0 %then %do;
 %let inlib = &library.;
%end;

%if %length(&refdate.) > 0 %then %do;
 %let inlib = WORK;
%end;

/* Re-define libname to read data from a non-standard directory */
%if %length(&altdir.) > 0 %then %do; 
 libname &library. "&altdir.";
%end; 

/********************************************
  Find out the &refdate associated format 
*********************************************/
proc sql noprint;
  select 
    format into: dtvarfmt
  from 
    dictionary.columns
  where 
    upcase(libname) = "%upcase(&library)"
    and
    upcase(memname) = "%upcase(&data)"
    and
    upcase(name)    = "%upcase(&refdate)"
  ;
quit;

/*******************************************************************
   Cummulative Data:
   - get start and end dates based on refdate
*******************************************************************/
%if %length(&refdate.) > 0 %then %do; 

 %if %length(&start.) = 0 %then %do;
  proc sql noprint; 
   select 
      %if %sysfunc(compress(&dtvarfmt, ., d)) = DATE %then %do;
        put(min(&refdate.),year4.)
      %end;
      %if %sysfunc(compress(&dtvarfmt, ., d)) = DATETIME %then %do;
        put(datepart(min(&refdate.)), year4.)
      %end;
    into :start
     from &library..&data.
     where &refdate. is not missing
     ;
  quit;   
 %end;

 %if %length(&end.) = 0 %then %do;
  proc sql noprint;
   select 
      %if %sysfunc(compress(&dtvarfmt, ., d)) = DATE %then %do;
        put(max(&refdate.),year4.)
      %end;
      %if %sysfunc(compress(&dtvarfmt, ., d)) = DATETIME %then %do;
        put(datepart(max(&refdate.)), year4.)
      %end;
    into :end
     from &library..&data.
     ;
  quit;
  

  /* If max end date is greater than current yet, set end to current year */
  data _null_;
   call symputx("currentyear",put("&sysdate."d,year4.),'L');
  run;  
 
  %if &end. > &currentyear. %then %do;
   data _null_;
    call symputx("end",put("&sysdate."d,year4.),'L');
   run;  
  %end;
  
 %end;
 
%end;

/*******************************************************************
   Convert year to fiscal year depending on data holding
*******************************************************************/
/******************************************************************
***************  Commented Out (06/12/2016) - Sean Ji *************

%if %sysfunc(find(&fiscaldata.,&data.)) > 0 %then %do; 
 %let yeartype = fiscal;
%end;

%else %do;
 %let yeartype = calendar;
%end; 
*********************  End Commenting Out **************************
********************************************************************/


/*******************************************************************
   Reduce max year for fiscal data if necessary
*******************************************************************/
%if %lowcase(&time.) = fiscal %then %do;

 %if %length(&refdate.) > 0 %then %do; 
   proc sql noprint;
    select count(*)
     into :nobsfiscalend
     from &library..&data.(obs=&n.)
      where 
        %if %sysfunc(compress(&dtvarfmt, ., d)) = DATE %then %do;
          "01APR&end."d <= &refdate. < "31MAR%eval(&end.+1)"d
        %end;
        %if %sysfunc(compress(&dtvarfmt, ., d)) = DATETIME %then %do;
          "01APR&end."d <= datepart(&refdate.) < "31MAR%eval(&end.+1)"d
        %end;
      ;
   quit;
 %end;
 %else %do;
   proc sql noprint;
    select count(*)
     into :nobsfiscalend
     from &library..&data.&end(obs=&n.)
      ;
   quit;
 %end;

 /* If no data exists in end year after April 1st, then reduce end year by 1 */
 %if &nobsfiscalend. = 0 %then %do;
  %let end = %eval(&end.-1);
 %end; 

%end; 

/*******************************************************************
   Create frequency tables by year for each variable
*******************************************************************/
%do year=&start. %to &end.;

 /* For cumulative datasets, split into yearly files by either fiscal
    or calendar year */
 %if %length(&refdate.) > 0 %then %do;

  proc sql noprint;
   create table &data.&year. as
    select * from &library..&data.(obs=&n.)
     %if %lowcase(&time.) = calendar %then %do;
       %if %sysfunc(compress(&dtvarfmt, ., d)) = DATE %then %do;
         where year(&refdate.) = &year.
       %end;
       %if %sysfunc(compress(&dtvarfmt, ., d)) = DATETIME %then %do;
        where year(datepart(&refdate.)) = &year.
       %end;
     %end;
     %else %if %lowcase(&time.) = fiscal %then %do;
       %if %sysfunc(compress(&dtvarfmt, ., d)) = DATE %then %do;
         where "01APR&year."d <= &refdate. < "31MAR%eval(&year.+1)"d
       %end;
       %if %sysfunc(compress(&dtvarfmt, ., d)) = DATETIME %then %do;
         where "01APR&year."d <= datepart(&refdate.) < "31MAR%eval(&year.+1)"d
       %end;
     %end; 
     ;
  quit;

 %end;

  /* Create macro variable with list of all variables in dataset for each year */
  proc sql noprint;
   select upcase(name) 
    into :allvars separated by " "
     from dictionary.columns
      where libname="&inlib." 
       and memname="&data.&year"
     ;
  quit;
 
/*******************************************************************
   Create formats for missing values
*******************************************************************/
proc format library=work;
 value $missing
     ' '   = 'Missing'
     other = 'Present'
 ;
 value missing
     .     = 'Missing'
     other = 'Present'
 ;
run;  

/*******************************************************************
   Loop through all variables and output missing frequency
*******************************************************************/
 %let i=1;
 %do %until (%scan(&allvars.,&i.)= );

  %let var=%scan(&allvars.,&i.);

  /* Create unique dataset names */
  %if %length(&var.) > 24 %then %do;
   %let varnameyear=%substr(__&var.,1,24)__&year.;
  %end;
  %else %do;
   %let varnameyear=__&var.__&year.;
  %end; 

  /* Initialize table */
  data &varnameyear.;
   _filler_='X';
  run;


  /* Get missing frequencies */
  proc freq data=&inlib..&data.&year.(obs=&n.) noprint;
   tables &var. /missing
    out=&varnameyear.(drop=count rename=(&var.=missing_flag percent=count&year.));
   format _numeric_ missing. _character_ $missing.;
  run;

  /* Add label, format and keep only missing percentages */
  data &varnameyear.;
   format varname $32.
          count&year. 15.13;
   set &varnameyear.;

   label count&year = "&year.";

   varname="&var.";

   /* Add 0 row for those variables with 100% present */
   if not missing(missing_flag) and count&year. > 99.9999999999999 then do;
    missing_flag = ' ';
    count&year. = 0;
   end; 

   /* Remove percentages corresponding to 'Present' */
   if not missing(missing_flag) then delete;

   drop missing_flag;

  run;
 
  %let i=%eval(&i.+1);
 %end;

%end;

/*******************************************************************
   Combine all frequency tables and output
*******************************************************************/
/* make sure the length of &data is not more than 18, otherwise   */
/* &data._tim will be more than 32, which will cause    */
/* an syntax error                                                */
%local ds;
%if %length(&data) > 18 %then %do;
  %let ds=%substr(&data,1,18);
%end;
%else %do;
  %let ds=&data;
%end;

/* Create empty dataset to initialize all variables */
data &ds._tim;
 format  varname $32.
        %do year=&start. %to &end.;
         count&year. 15.13
        %end;
        ;
run;        

 /* Loop through each year */
 %do year=&start. %to &end.;

  /* Get list of variables from given year */
  proc sql noprint;
   select upcase(name) 
    into :allvars separated by " "
     from dictionary.columns
      where libname="&inlib." 
       and memname="&data.&year"
     ;
  quit;

  /* Get number of observations from each year */
  proc sql noprint;
   select nobs 
    into :nobs&year. 
     from dictionary.tables
      where libname="&inlib."
       and memname="&data.&year."
       ;
   quit;

   /* If testing, output testn instead */
   %if %length(&testn.) > 0 %then %do;
    %let nobs&year. = &testn.;
   %end; 

 %let j=1;
 %do %until (%scan(&allvars,&j.)= );

  %let var=%scan(&allvars,&j.);
  
  /* Get unique dataset names */
  %if %length(&var.) > 24 %then %do;
   %let varname=%substr(__&var.,1,24)__;
  %end;
  %else %do;
   %let varname=__&var.__;
  %end; 

  /* Verify file was not already created */
  %if %sysfunc(exist(&varname.freq)) = 0 %then %do; 

   data &varname.freq;
    merge &varname.:;
   run; 

   proc sort data=&varname.freq nodupkey;
    by _all_;
   run; 
   
   /* Combine frequency tables */
   proc append
    base=&ds._tim
    data=&varname.freq
    force nowarn;
   run; 

  %end; 

  %let j=%eval(&j.+1);
 
 %end;

%end;

/*******************************************************************
   Create dataset with observation numbers
*******************************************************************/
%put _user_;
data _nobs;
 format  varname $32.
         label $256.
        %do year=&start. %to &end.;
         count&year. 15.13
        %end;
        ;

 label='Number of Observations';

 %do year=&start. %to &end.;
  count&year.=&&nobs&year.;
 %end; 
 
run;        

/*******************************************************************
   Delete all work datasets
*******************************************************************/
%do year=&start. %to &end.;

 /* Get list of variables from given year */
 proc sql noprint;
  select upcase(name) 
   into :allvars separated by " "
    from dictionary.columns
     where libname="&inlib." 
      and memname="&data.&year"
    ;
 quit;
  
 %let k=1;
 %do %until (%scan(&allvars,&k.)= );

  %let var=%scan(&allvars,&k.);
 
  %if %length(&var.) > 24 %then %do;
   %let varname=%substr(__&var.,1,24)__;
  %end;
  %else %do;
   %let varname=__&var.__;
  %end;

  /* Delete datasets while hiding from log */
  options nonotes nomprint;
  
  proc datasets library=work nolist;
   delete &varname.&year. &varname.freq;
  run;
  
  options notes mprint;
  
 %let k=%eval(&k.+1);
 
 %end;

%end; 


/*******************************************************************
   Restore original options
*******************************************************************/
proc optload key="core\options";
run;

/*******************************************************************
   Remove blank row(s) and ref date 
*******************************************************************/
data &ds._tim;
 set &ds._tim;
  where not missing(varname);

 %if %length(&refdate.) > 0 %then %do;
  if varname="&refdate." then delete;
 %end; 
run; 

proc sort data=&ds._tim;
 by varname;
run;

/*******************************************************************
   Add labels to report
   - Replace tabs with spaces in labels
*******************************************************************/
%do year=&start. %to &end.;

 proc sql noprint;
  create table labels&year. as
  select upcase(name) as varname,label as label0 
    from dictionary.columns
     where libname="&inlib." 
      and memname="&data.&year"
       order by varname
    ;
 quit;

 data &ds._tim;
  length label $256;
  merge &ds._tim(in=a) labels&year.(in=b);
   by varname;

  if a;

  if missing(label) and not missing(label0) then do;
   label=translate(label0," ","09"x);
  end;

  drop label0;
 run; 

 proc datasets library=work nolist nodetails;
  delete labels&year.;
 run; 

%end;

proc sort data=&ds._tim;
 by varname;
run; 

/*******************************************************************
   - Add filler to bottom row for easier formatting in Excel 
     later
   - Apply labels to report  
*******************************************************************/
data &ds._tim;
 set &ds._tim end=eof;
 
 label varname='Variable Name'
       label='Variable Label'
       %do year=&start. %to &end.;
        count&year.="&year."
       %end; 
       ;
 output;      
 if eof then do;
  varname='filler';
  label='filler';
  count&start.=100;
  output;
 end;

run;

/*******************************************************************
   Add record with number of observations for each year
*******************************************************************/
data &ds._tim;
 set _nobs
     &ds._tim;
run;     
  
/*******************************************************************
   Output report to tab delimited text file
*******************************************************************/
/* Re-order variables */
data &ds._tim;
 retain varname label count&end-count&start.;
 set &ds._tim;
run; 

/* Create titles for yearly datasets */
%if %length(&refdate.) = 0 %then %do;
 %let maintitle = &library..&data.yyyy;
 %let subtitle = Percentage of Missing Values Over Time, based on the yearly datasets;  
%end;

/* Generate the html format report */
 %tim_html(
    data = &ds._tim,
    title_lib=&library,
    title_ds=&data,
    title_yrtype=&time,
    title_refvar=&refdate,
    htmlpath=&path,
    startyr = &start,
    endyr = &end
    )


/* Delete interim datasets*/

	proc datasets lib=work;
		delete &data.&start - &data.&end &data._tim;
	quit;

%mend tim;


