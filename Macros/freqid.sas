/*========================================================================  
DataFit Toolkit - FreqID macro
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


*****************************************************************************;
** Macro:      freqid.sas

** Job:        Data Quality

** Date:       March 2013

** Programmer: Xiaoping Zhao

** Purpose:  This macro will check each ID variable listed in ID= paramter
              (separated by space) and attach one of the following comments:

               - "Unique" (if it was unique and no missing values)
               - "Unique when not missing" (if there were missing values
                  but the ID was unique for the rest of the observations)
               - "Not Unique" (otherwise.)

              If it is Not Unique, a frequency of occurrences table will
              be provided for the ID variable.

              Two ways to run this macro:
                - to be called in %vimo macro
                - stand alone run by providing values for each paramter.

** Parameters:
              callin - T/F flag to decide which way to run this macro.
                       Default: T (true), it will be called in %vimo

              Data -   two level dataset name
                       Default: macro variable DS in %vimo

              idlist - list of ID variables separated by blanks
                       Default: macro variable ID in %vimo

** Example 1: %freqid - to be called within %vimo macro

** Example 2: %freqid(callin=f,
                      data =cic.cic,
                      idlist =cickey ikn);
** Update:    May 2014 (Sean Ji)
              Use format best32. to replace default format best8. in
              PROC SQL to generate macro variables. Avoid macro
              variables containing scientific notation, which causes 
              syntax error when these variables are using in %IF
              statement.
         
              Nov 2016, Mahmoud Azimaee
              - Major updates on all macros in order to make them compatible with SAS PC 

              Dec 2016, Sean Ji
              - fixed the issue that counting more id variables than the real number of
                id variables in the macro variable &idlist

              Dec 2016, Sean Ji
              - fixed the bug: when an id variable is numeric and it's unique, after
                clicking the link for the id variable, there is no freq table show up
 
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/;

%macro freqid(
  callin=T,
  Data=&ds,
  idlist=&id
);

 
 %if %index(&data, .) %then %do;
  %let libref=%scan(&data,1,'.');
  %let dsname=%scan(&data,2,'.');
 %end;
 %else %do;
   %let libref=work;
   %let dsname=&data;
 %end;

 %if %length(&idlist) >0 %then %do;
 %let nofid =%eval(%SYSFUNC(COUNTW(%sysfunc(strip(&idlist)),' ')));

 %do f=1 %to &nofid;
  
  %let idvar=%scan(%sysfunc(strip(&idlist)), &f, ' ');
  data mdata nonmdata;
   set &data(keep=&idvar);

    if MISSING(&idvar) then output mdata;
    else output nonmdata;
  run;

  proc sql noprint;
   select nobs format=best32. into :misscnt from dictionary.tables
   where libname='WORK' and memname='MDATA';
  quit;

  proc sort data=nonmdata;
   by &idvar;
  run;

  data nonmdata;
   set nonmdata;
   by &idvar;

   if first.&idvar then nofrec=0;
   nofrec+1;

   if last.&idvar;
   label nofrec='number of occurrence';
  run;


  proc freq data=nonmdata noprint;
   tables nofrec/out=nonmdata;
  run;


  proc sql noprint;
   *** get the maximum number of occurrencs an ID variable occurred in the data ;
   select max(nofrec)  format=best32. into :maxnofrec from nonmdata;
  quit;

  proc means data=nonmdata noprint;
    var count;
    output out=ttc(drop=_:) sum=ttc;
  run;
  data _null_;
    set ttc;

    call symput ('tt', ttc);
 run;
 proc delete data=ttc; run;

  data nonmdata;
    length value $50;
    set nonmdata end=last;
    value=strip(nofrec);
    percent=percent/100;
    output;
    if last then do;
       value="Total # of distinct &idvar.s";
       count=%eval(&tt);
       percent=1;
       output;
    end;
    drop nofrec;
  run;

 %if &maxnofrec =1 and &misscnt=0 %then %let comments =Unique;
 %else %if &maxnofrec =1 and &misscnt   %then %let comments =%str(Unique when not missing);
 %else %if &maxnofrec ^=1 %then %let comments =%str(Not unique);

 %if %upcase(&callin) =F %then %do;
  options formdlim='~';
   data &idvar;
    length comments $100;
    comments="In dataset &data, the variable %upcase(&idvar) is %lowcase(&comments).";
  run;

  proc print data=&idvar noobs;
  run;

  %if &maxnofrec ^=1 %then %do;
   data nonmdata;
     set nonmdata;
     label value ="Number of records per %upcase(&idvar)"
           count ="Number of %upcase(&idvar)s"
           percent="Percent of %upcase(&idvar)s";
   run;

   proc print data=nonmdata noobs label;
   format count comma12.0 percent percent8.2;
   run;
  %end;
   title;
 %end;

 %else %do;
 *** create iddata freqdata for vimo ***;
   data &idvar;
     length varname $32 comments $30;
     varname=upcase("&idvar");
     comments="&comments";
   run;

   data nonmdata;
    set nonmdata;
     length varname $32;
     varname=upcase("&idvar");

     seq=_n_; *** temp var to keep order of output;
   run;

   proc datasets lib=work mt=data nolist;
    append base=iddata data=&idvar(rename=(comments=invalid_codes)) force;
    /******************************************************************
    ***************  Commented Out (12/12/2016) - Sean Ji *************

    %if &maxnofrec ^=1 %then %do;
    *********************  End Commenting Out **************************
    ********************************************************************/
     append base=freqdata data=nonmdata force;
    /******************************************************************
    ***************  Commented Out (12/12/2016) - Sean Ji *************

    %end;
    *********************  End Commenting Out **************************
    ********************************************************************/
 
    delete mdata nonmdata &idvar;
   quit;
 %end;

%end;

%if &callin =T %then %do;
   proc sql;
    create table miss_ as
    select m.*, coalescec(i.invalid_codes, m.invalid_codes) as comments
    from miss m left join iddata i
    on m.varname=i.varname;
   quit;

   data miss;
     set miss_(drop=invalid_codes);
     rename comments=invalid_codes;
   run;

   %if %sysfunc(exist(freqdata)) %then %do;
   proc sql noprint;
    select distinct quote(strip(varname)) into :idlist separated by ',' from freqdata;
   quit;

   data charfreq;
     set charfreq(where=(varname not in (&idlist)))
         freqdata
         ;
   run;

   %end;
   
   proc datasets lib=work;
      delete iddata %if %sysfunc(exist(freqdata)) %then %do; freqdata %end;;
   quit;
   
%end;
%end;

%mend freqid;
