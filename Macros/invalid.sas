/*========================================================================  
DataFit Toolkit - Invalid macro
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
  | MACRO:       INVALID
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        May 2011
  |
  | DESCRIPTION: This macro uses the WORK.CHARFREQ dataset created by
  |              %CHARFREQ to to compare it against the Fromats assigned to
  |              charachter variables. It also generate a simillar file to
  |              CHARFREQ for numeric variables with a format assigned.
  |              This comparision is used for generating INVALIDS dataset
  |              in the WORK library to report percentage of invalid
  |              values.
  |              This is an intermediate macro and will be called by %VIMO
  |
  | PARAMETERS:  DS= Dataset name
  |
  |              METALIB= SAS library name containing METADATA
  |                       (Default is Meta)
  |
  |              FMTLIB= SAS library name containing Formats
  |
  | EXAMPLE:     %INVALID(DS=&DS, FMTLIB=&FMTLIB, METALIB=&METALIB)
  |  UPDATE:     April 2014 (Sean Ji) 
  |              - solve the issue: filling up SASTMP directory
  |              - suppressesed printing of error messages and prevented 
  |                the automatic variable _ERROR_ from being set to 1 
  |                when invalid data are read into INPUT function
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%MACRO INVALID (DS=, METALIB=META, FMTLIB=);
        %local fmtlist varlist I DOI;
        %let fmtlist=;
        %let varlist=;
        options FMTSEARCH = (&FMTLIB);

        data VARIABLES;
           set &METALIB..metadata;
           if libname="&LIB" & memname="&DSN" & format^ in ('', '$');
           keep NAME FORMAT FMTNAME TYPE;
           FMTNAME=COMPRESS(FORMAT,'$');
           TYPE=substr(TYPE,1,1); **update;
        run;

        PROC SQL NOPRINT;
                SELECT FORMAT INTO :FMTLIST SEPARATED BY " "
                  FROM VARIABLES;
                SELECT NAME INTO :VARLIST SEPARATED BY " "
                  FROM VARIABLES;
        QUIT;

        proc format library=&FMTLIB..formats  cntlout=VALIDS (keep=FMTNAME START END TYPE LABEL HLO);
             %if %length(&FMTLIST) gt 0 %then %do;
                select &FMTLIST;
             %end;
        run;

       *** Flag HLO='O' (OTHER) formats (or combination of F and other values) in VALIDS dataset;

        DATA OTHERFMT;
          SET VALIDS;
          IF INDEX(HLO ,'O');
          KEEP FMTNAME;
        RUN;

        PROC SORT DATA=VALIDS; BY FMTNAME; RUN;
        PROC SORT DATA=VARIABLES; BY FMTNAME; RUN;
        proc sort data=otherfmt; by fmtname; run;

        DATA VALIDS;
          MERGE VALIDS OTHERFMT(IN=IN_OTHER);
          BY FMTNAME;
          IF IN_OTHER THEN OTHER=1;
          ELSE OTHER=0;
        RUN;

        DATA VARIABLES;
           MERGE VARIABLES VALIDS (IN=IN_VALID);
           BY FMTNAME ;
           IF IN_VALID;
        RUN;

        DATA VALIDS;
           SET VALIDS;
           START=STRIP(START);
           END=STRIP(END);
        RUN;

        PROC SORT DATA=VARIABLES (KEEP=NAME FMTNAME FORMAT OTHER TYPE) NODUPKEY;
           BY NAME FMTNAME;
        RUN;

        %LET VARLIST= ;
        %LET FMTLIST= ;

        PROC SQL NOPRINT;
                SELECT FORMAT INTO :FMTLIST SEPARATED BY " "
                  FROM VARIABLES
                  WHERE TYPE='N';
                SELECT NAME INTO :VARLIST SEPARATED BY " "
                  FROM VARIABLES
                  WHERE TYPE='N';
        QUIT;

        %LET DOI=%EVAL(%SYSFUNC(COUNTC(&VARLIST,' '))+1);

        %IF %LENGTH(&VARLIST) ^= 0 %THEN %DO;
        %DO I=1 %TO &DOI;
                %LET VAR=%SCAN(&VARLIST,&I," ");
                %LET FMT=%SCAN(&FMTLIST,&I," ");
                %IF %SUBSTR(&FMT,1,1)=$ %THEN %DO;
                        proc sql;
                          create table VALUE&I as
                          select put(&VAR, $32.) as VALUE ,
                                         count(&VAR) as Count
                                         from &LIB..&DSN
                          group by (&VAR)
                          order by VALUE;
                          quit;
                %END;
                %ELSE %DO;
                        proc sql;
                          create table VALUE&I as
                          select put(&VAR, BEST32.) as VALUE ,
                                         count(&VAR) as Count
                                         from &LIB..&DSN
                          group by (&VAR)
                          order by VALUE;
                          quit;
                %END;
                data VALUE&I;
                        set VALUE&I;
                        length VARNAME FMTNAME $32;
                        FMTNAME=SYMGETC('FMT');
                        VARNAME=SYMGETC('VAR');
                run;
        %END;

          Data ValuesNUM;
                set VALUE1 - VALUE&DOI;
                BY FMTNAME;
                VALUE=STRIP(VALUE);
                IF VALUE IN ('','.') THEN DELETE;
                FMTNAME=COMPRESS(FMTNAME,'$');
          run;

          PROC SORT DATA=VALUESNUM ; BY VARNAME VALUE; RUN;

      %END;

        DATA ValuesCHAR;
            SET CHARFREQ;
            IF VALUE='' THEN DELETE;
            DROP MISSING;
        RUN;

        PROC SORT DATA=VALUESCHAR; BY VARNAME VALUE; RUN;
        PROC SORT DATA=VARIABLES; BY NAME ; RUN;

        %IF %LENGTH(&VARLIST) ^= 0 %THEN %DO;
          DATA VALUES;
             MERGE VALUESNUM  (IN=IN_NUM)
                   VALUESCHAR (IN=IN_CHAR)
                   VARIABLES  (IN=IN_VARS RENAME=(NAME=VARNAME));
             BY VARNAME;
            IF IN_VARS & (IN_NUM | IN_CHAR);

          RUN;
        %END;
        %ELSE %DO;
          DATA VALUES;
             MERGE VALUESCHAR (IN=IN_CHAR)
                   VARIABLES  (IN=IN_VARS RENAME=(NAME=VARNAME));
             BY VARNAME;
             IF IN_VARS & IN_CHAR;
          RUN;
        %END;

        data valids;
          set valids;
          startnum=input(start, ?? best12.);
          endnum  =input(end, ?? best12.);
        run;

        data values;
          set values;
          valuenum=input(value, ?? best12.);
        run;


        proc sql;
          create table valid_values(drop=count fmtname valuenum) as
            select a.*,
                   b.start,
                   b.end
            from   values as a,
                   valids as b
            where  (a.fmtname=b.fmtname)  and
                   (
                      (b.start <= a.value <= b.end) or
                      (b.startnum ^=. and b.endnum ^=. and
                       b.startnum <= a.valuenum <= b.endnum)
                   )  
          ;
        quit;
        run;

        data valids;
          set valids(drop=startnum endnum);
        run;

        data values;
          set values(drop=valuenum);
        run;

        PROC SORT DATA=VALUES; BY VARNAME VALUE; RUN;
        PROC SORT DATA=VALID_VALUES; BY VARNAME VALUE; RUN;

        DATA VALUES;
          MERGE VALUES (IN=IN_ALL) VALID_VALUES (IN=IN_VALID);
          BY VARNAME VALUE;
          IF IN_VALID THEN VALID=1;
          ELSE VALID=0;
        RUN;

        PROC MEANS DATA=VALUES NOPRINT;
                 CLASS VARNAME;
                 VAR COUNT;
                 WHERE ^VALID;
                 OUTPUT OUT=INVALIDS SUM=INVALID;
                 RUN;

        data INVALIDS;
                set INVALIDS;
                if _TYPE_ = 1;
                drop _TYPE_ _FREQ_ ;
                label Invalid='# of Invalid Codes';
                run;


        PROC SQL NOPRINT;
                SELECT NAME INTO :VARLIST SEPARATED BY " "
                  FROM VARIABLES;
        QUIT;

        %LET DOI=%EVAL(%SYSFUNC(COUNTC(&VARLIST,' '))+1);

        %DO I=1 %TO &DOI;
                %LET VAR=%UPCASE(%SCAN(&VARLIST,&I," "));
                PROC SQL NOPRINT;
                        SELECT VALUE INTO :INVALID SEPARATED BY ", "
                          FROM VALUES
                          WHERE VARNAME="&VAR" & VALID=0;
                QUIT;

        data INVALIDS;
                set INVALIDS;
                length INVALID_CODES $ 500 ;
                if VARNAME="&VAR" then INVALID_CODES='Invalid Codes: ' ||SYMGETC('INVALID');
                run;
        %END;

        PROC SORT DATA=INVALIDS; BY VARNAME; RUN;
        PROC SORT DATA=VARIABLES (RENAME=(NAME=VARNAME)); BY VARNAME; RUN;

        DATA INVALIDS;
          MERGE INVALIDS VARIABLES(IN=IN_OTHER KEEP=VARNAME OTHER);
          BY VARNAME;
          IF OTHER THEN DO;
              INVALID_CODES="Format includes 'OTHER', Validation can not be done";
              INVALID=.;
          END;
          DROP OTHER;
        RUN;

 %MEND INVALID;
