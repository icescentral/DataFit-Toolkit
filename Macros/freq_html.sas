/*========================================================================  
DataFit Toolkit - Freq HTML macro
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


/*__________________________________________________________________________
  | MACRO:       FREQ_HTML
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        October 2012
  |
  | DESCRIPTION: This macro uses the WORK.CHARFREQ dataset created by
  |              %CHARFREQ to create HTML pages displaying frequency
  |              tables for each character variable. Pages will be saved
  |              in a subolder called "Freq" under the &PATH. Note that
  |              this subfolder must be created prior running the macro.
  |              This is an intermediate macro and will be called by %VIMO
  |
  | PARAMETERS:  PATH= physical location for storinh HTML pages (note: do
  |              not include /Freq )
  |
  |              METALIB= Name of the SAS Library containing Metadata
  |
  | EXAMPLE:     %FREQ_HTML(PATH=&PATH, METALIB=&METALIB)
  |
  |  UPDATE:     May 2013 (Xiaoping Zhao)
  |              - incorporate frequency id variable contents from macro
  |                %freqid into this freq_html macro.
  |              - add variable label to the individual frequency table
  |              - conditional output col2 (description) in frequency table
  |                if variable with format, output col2, otherwise not.
  |
  |              July 2013 (Xiaoping Zhao)
  |              - fix character variables whose values are numeric to be sorted in
  |               a more logical order.
  |               ie. output value in the order of 1,2,3...10,11,...,
  |               not in 1,10,11..,2,20,..3,4..., etc.
  |
  |              August 2013 (Xiaoping Zhao)
  |              - create dummy realidvars macro variable to avoid the macro
  |                stops if no ID variable in the data.
  |
  |              August 27/Sept 5 2013 (xiaoping Zhao)
  |              - for ID vars with unique values, add nonmissing unique value counts
  |                into their individual frequency table
  |
  |              March 2014 (Sean Ji)
  |              - when format name is 32 characters long,the macro variable &FMT
  |                do not have dot(.) at the end, add code solve this problem
  |
  |              April 2014 (Sean Ji)
  |              - Based on the parameter TIME, generate frequency tables
  |                for date or datetime variables
  |
  |              May 12 2014 (Sean Ji)
  |              - fixed the bug: when there is no date variable,
  |                               IN operator causes error.
  |
  |              Oct 6 2014 (Gangamma Kalappa)
  |              - fixed the bug: a) Formatted values column not displayed in
  |                                  html page of numerical variables
  |                                  with user defined formats.
  |                               b) Formatted values appears as blank when
  |                                  formatted value same as variable value.
  |               Oct 17 2014 (Gangamma Kalappa)
  |               -Generate a frequency table for time variable (variables with
  |                TIME format) .
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |
  |              Dec 2016, Sean Ji
  |              - fixed the bug: when an id variable is numeric and it's unique, after
  |                clicking the link for the id variable, there is no freq table show up
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
%MACRO FREQ_HTML (PATH=, METALIB=);
   %LET NESTEDFMTS = "";
   %LET NESTEDFMTVARS = "";
   PROC SQL NOPRINT;
        CREATE TABLE nestedvar AS
        SELECT FORMAT, VARNAME FROM VARIABLES;
   QUIT;
   PROC SQL NOPRINT;
        SELECT DISTINCT quote(strip(fmtname)) INTO : NESTEDFMTS SEPARATED BY ","
                FROM VALIDS
                WHERE HLO="F";
    QUIT;
    DATA nestedvar;
         SET nestedvar;
         IF FORMAT IN (&NESTEDFMTS) THEN DO;
               NESTEDFMT=1;
         END;
         ELSE NESTEDFMT=0;
    RUN;
    PROC SQL NOPRINT;
        SELECT DISTINCT quote(strip(VARNAME)) INTO : NESTEDFMTVARS SEPARATED BY ","
                FROM nestedvar
                WHERE NESTEDFMT=1;
    QUIT;

  %local i;

  %GETNOBS(&LIB..&DSN);

  *** Get the formats of variables from Metadata, if available;
  data FORMATS (RENAME=(NAME=VARNAME));
     set &METALIB..metadata;
     if libname="&LIB" & memname="&DSN" & format^ in ('', '$', 'BEST','Z')
        %if %length(&qnumvarfmtlist) >0  %then %do; and upcase(NAME) not in (&qnumvarfmtlist) %end;
     ; 

     keep NAME FORMATDOT;
  run;

  ***update: check if data formats with 0 obs, if not, run below do-loop ***;
  proc sql noprint;
    select nlobs into :obscnt from dictionary.tables
    where libname ='WORK' and memname='FORMATS';
  quit;

  %if &obscnt %then %do;

  PROC SQL NOPRINT;
    SELECT VARNAME INTO: VARLIST SEPARATED " "
    FROM FORMATS;
    SELECT FORMATDOT INTO: FMTLIST SEPARATED " "
    FROM FORMATS;
  QUIT;

  %LET DOI=%EVAL(%SYSFUNC(COUNTC(&VARLIST,' '))+1);

  %DO I=1 %TO &DOI;
    %LET VAR=%SCAN(&VARLIST,&I," ");
    %LET FMT=%SCAN(&FMTLIST,&I," ");

    %if %sysfunc(findc(&fmt, .)) eq 0 %then %do;
      %let fmt=&fmt..;
    %end;
    %if %index(&fmt, DATE) %then %do;
      %let fmt=$100.;
    %end;
    %if %index(&fmt, TIME) %then %do;
      %let fmt=$100.;
    %end;

   DATA CHARFREQ;
       LENGTH FORMATTEDVALUE $100 ;
       SET CHARFREQ;
       IF VARNAME="&VAR" THEN FORMATTEDVALUE=PUT(COMPRESS(VALUE),&FMT);
    RUN;
  %END;

  %end;


  proc sql noprint;
    select count(*) into :seqexist from dictionary.columns
    where libname='WORK' and memname='CHARFREQ' and upcase(name)='SEQ';
  quit;

  DATA FREQ;
    SET CHARFREQ;
    IF VALUE='' THEN DO;
       COUNT=MISSING;
       VALUE='(Missing Value)';
    END;

    IF FORMATTEDVALUE=VALUE THEN DO;
        IF VARNAME NOT IN (&NESTEDFMTVARS) THEN  FORMATTEDVALUE='';
    END;

    ***update: do not compute percent for id vars, var seq not missing for id vars ***;
    %if %length(&REALIDVARS) gt 0 and &seqexist %then %do;
      if seq <0 then do;
       PERCENT=COUNT/SYMGETN('NO');
      end;
    %end;
    %else %do;
       PERCENT=COUNT/SYMGETN('NO');
    %end;

    FORMAT COUNT COMMA32.0 PERCENT PERCENT10.2;
    DROP MISSING;

    /*updated on March 24, 2014: variable ordervar is used later for sorting */
    if %length(&qdatevars) = 0 then do;
      /* Avoid syntax error when using qdatevars */
      /* as operand of macro IN operator         */
      %let qdatevars="_";
      ordervar=right(VALUE);
    end;
    else if varname in (&qdatevars) then do;
      /********************UPDATE: April, 2014*****************************
          deal with the month format, e.g. tranfer 1999M04 to 1999APR
          due to the order issue of month format
      *********************************************************************/
      ordervar=value;
      if index(value,'M') and %upcase("&time") eq "MONTHLY" then do;
         select (strip(reverse(substr(reverse(strip(value)),1,2))));
          when ('01') value = cats(substr(strip(value),1,4),'JAN');
          when ('02') value = cats(substr(strip(value),1,4),'FEB');
          when ('03') value = cats(substr(strip(value),1,4),'MAR');
          when ('04') value = cats(substr(strip(value),1,4),'APR');
          when ('05') value = cats(substr(strip(value),1,4),'MAY');
          when ('06') value = cats(substr(strip(value),1,4),'JUN');
          when ('07') value = cats(substr(strip(value),1,4),'JUL');
          when ('08') value = cats(substr(strip(value),1,4),'AUG');
          when ('09') value = cats(substr(strip(value),1,4),'SEP');
          when ('10') value = cats(substr(strip(value),1,4),'OCT');
          when ('11') value = cats(substr(strip(value),1,4),'NOV');
          when ('12') value = cats(substr(strip(value),1,4),'DEC');
          otherwise;
         end;
      end;
    end;

    ln0=length(ordervar)-length(VALUE);
    if ln0>0 then ordervar=repeat('0',(ln0 -1))||strip(ordervar);
    drop ln0;

  RUN;

  PROC SORT DATA=FREQ;
    BY VARNAME ORDERVAR;  /*update: sort data by ORDERVAR to have value in 1,2,..10.. order*/

  RUN;

  ***update: sort ID vars by seq ***;
  %if %length(&REALIDVARS) gt 0 and &seqexist %then %do;
   proc sort data=FREQ out=idvars; 
     where seq;
     by varname seq;
   run;

   data FREQ;
    set FREQ(where=(seq<0))
        idvars; 
    drop seq;
   run;
   
  %end;
  ***********************************;

  ***update: for ID vars with unique values, add nonmissing unique value counts into their individual frequency table;
  proc sql noprint;
    select quote(strip(varname)) into :uvars separated by ',' from miss
    where lowcase(substr(invalid_codes,1,6)) ='unique';
  quit;

  %if &sqlobs %then %do;
   data uvars freq;
      set freq;
      if varname in (&uvars) then output uvars;
      else output freq;
   run;

   data uvars_;
      set uvars;
      if value = '1' then do;
        value='Nonmissing Unique Value';
        formattedvalue='Nonmissing Unique Value';
        ordervar='1';
      end;
      if substr(value, 1, 19) = "Total # of distinct" then delete;
   run;

   data uvars;
      set uvars(in=m where = (strip(value) ne '1'))
          uvars_
          ;
      if m then do;
         ordervar='2';
         formattedvalue=value;
      end;
   run;
   proc sort data=uvars; by varname ordervar; run;

   data freq;
      set freq uvars;
   run;
  %end;

  **********end of update *******************************************************;


  PROC SQL NOPRINT;
    SELECT DISTINCT(VARNAME) INTO: VARLIST SEPARATED " "
    FROM FREQ;
  QUIT;


  %LET DOI=%EVAL(%SYSFUNC(COUNTC(&VARLIST,' '))+1);

  /* get the macro variable &dategrp according to parameter TIME       */
  /* &dategrp is using for the header of date variable frequency table */
  %if %upcase(&time)=FISCAL %then %do;
    %let dategrp=By Fiscal Year;
  %end;
  %else %if %upcase(&time)=CALENDAR  %then %do;
    %let dategrp=By Calendar Year;
  %end;
  %else %if %upcase(&time)=QUARTERLY %then %do;
    %let dategrp=By Quarter;
  %end;
  %else %if %upcase(&time)=MONTHLY %then %do;
    %let dategrp=By Month;
  %end;

  %if %length(&timevars)=0 %then %do;
       %let timevars=dummy; 
  %end;

  %DO I=1 %TO &DOI;
     %LET VAR=%SCAN(&VARLIST,&I," ");
     %let fmt_var=0;

      %if %length(&REALIDVARS)=0 %then %do;
        %let idvars=dummy;
        %let realidvars=dummy; ***update: create dummy realidvars if no id vars in the data;
      %end;

      %if &VAR in &REALIDVARS %then %do;
       proc sql noprint;
         select strip(invalid_codes) into :comments from miss
         where varname="&VAR";
       quit;
      %end;
      %else %do;
       proc sql noprint;
         select strip(varlabel) into :varlabel from miss
         where varname="&VAR";
       quit;
      %end;

      proc sql noprint;
          select varname from formats where varname = "&VAR";
      quit;
      %let fmt_var=&sqlobs;   *** flag character varname with formats;


%if %length(&numvarfmtlist)=0 %then %do; %let numvarfmtlist=dummy; %end;

ods PATH work.templat(update) sasuser.templat(read) sashelp.tmplmst(read);
      proc template;
        define style defaultback;
          parent = styles.default;
          replace color_list /
            'bgA'  = cxFFFFFF
            'bgA1' = cxFFFFFF
            'bgA2' = cxFFFFFF
            'bgA3' = cxFFFFFF
            'bgA4' = cxFFFFFF
            'bgH' = cxFFFFFF
            'bgT' = cxFFFFFF
            'bgD' = cxFFFFFF
            'bg' = cxFFFFFF
            'fg' = cxFFFFFF;
        end;

        define table FREQPAGE;
          mvar titleone;
          dynamic categoryheader;
          column (col1) (col2) (COL3) (COL4) ;
          header table_header_1;
            define table_header_1;

              %if &VAR in &REALIDVARS %then %do;
              text "The variable &var is %lowcase(&comments) on dataset &DSN";
              %end;
              %else %do;
              text "Frequency Table For %upcase(&VAR):~n &varlabel";
              %end;

              style = {background = white font_face= 'Arial' Font_size=4 color = cx00669D just =c};
            end;

            define col1;
              generic=on;
              %if &VAR in &REALIDVARS %then %do;
                %if %substr(%upcase(&comments),1,1) ^=U %then %do;
                  header = "Number of records per &VAR";
                %end;
                %else %do;
                  header = 'Value';
                %end;
              %end;

              %else %if %length(&datevars)=0 %then %do;
                header = 'Value';
              %end;
              %else %if &var in &datevars %then %do;
                 header = "Date Group (&dategrp)";
              %end;
              %else %if &var in &timevars %then %do;
                 header = "Time Group (by hour)";
              %end;
              %else %do;
                header = 'Value';
              %end;

              %if &VAR in &REALIDVARS %then %do;
              style = {background = white font_face= 'Arial' Font_size=3 just =c};
              %end;
              %else %do;
              style = {background = white font_face= 'Arial' Font_size=3 };
              %end;
            end;

            define col2;
              generic=on;
              header = 'Description';
              style = {background = white font_face= 'Arial' Font_size=3 };
            end;

            define col3;
              generic=on;
              %if &VAR in &REALIDVARS %then %do;
                 %if %substr(%upcase(&comments),1,1) ^=U %then %do;
                   header = "Number of &var.s";
                 %end;
                 %else %do;
                   header = 'Frequency';
                 %end;
              %end;
              %else %do;
                   header = 'Frequency';
              %end;

              style = {background = white font_face= 'Arial' Font_size=3 };
            end;

            define col4;
              generic=on;
              %if (&VAR in &REALIDVARS) %then %do;
               %if %substr(%upcase(&comments),1,1) ^=U %then %do;
                  header = "Percent of &var.s";
               %end;
               %else %do;
                  header = 'Percent';
               %end;
              %end;
              %else %do;
                  header = 'Percent';
              %end;
              style = {background = white font_face= 'Arial' Font_size=3 };
            end;

        end;
      run;

      ods listing close;
      ods escapechar = '~';

      ods html file = "&path/Freq/%lowcase(&&var).html" (title = "Frequency Table - %upcase(&&var)");
              footnote bcolor = white color = cx00669D height = 2 justify = r "This page was last updated on %sysfunc(date(), worddate.)";

            %let titleone = ALL;

            /* Avoid sytanx error, when using &datevars as an operand of macro IN operator */
            %if %length(&datevars)=0 %then %do;
              %let datevars=_;
            %end;
            %if %length(&timevars)=0 %then %do;
              %let timevars=_;
            %end;

            title;
            data _null_;
              set FREQ (where = (VARNAME="&VAR"));


                %if &VAR in &numvarfmtlist %then %do;
                file print
                ods = (template='FREQPAGE'
                       columns=
                         (col1=value(generic=on)
                          col2=formattedvalue(generic=on)
                          col3=count(generic=on)
                          COL4=PERCENT(GENERIC=ON)
                      ));
               %end;

               %else %if &VAR in &REALIDVARS %then %do;
                file print
                ods = (template='FREQPAGE'
                       columns=
                         (col1=value(generic=on)

                          col3=count(generic=on)
                          COL4=PERCENT(GENERIC=ON)
                      ));

               %end;
                /***Oct 6,2014 update a) added else if instead of just if***/
               %else %if &var in &datevars %then %do;
                  file print
                  ods = (template='FREQPAGE'
                          columns=
                            (col1=value(generic=on)

                             col3=count(generic=on)
                             COL4=PERCENT(GENERIC=ON)
                         ));
               %end;
               %else %if &var in &timevars %then %do;
                 file print
                  ods = (template='FREQPAGE'
                          columns=
                            (col1=value(generic=on)

                             col3=count(generic=on)
                             COL4=PERCENT(GENERIC=ON)
                         ));
               %end;
               %else %if &fmt_var >0 %then %do;
                  file print
                  ods = (template='FREQPAGE'
                         columns=
                           (col1=value(generic=on)
                            col2=formattedvalue(generic=on)
                            col3=count(generic=on)
                            COL4=PERCENT(GENERIC=ON)
                        ));
               %end;

               %else %do;
                  file print
                  ods = (template='FREQPAGE'
                         columns=
                           (col1=value(generic=on)

                            col3=count(generic=on)
                            COL4=PERCENT(GENERIC=ON)
                        ));
               %end;

              put _ods_;

            run;
            ods html close;
  %END;

  ods listing;

%MEND FREQ_HTML;
