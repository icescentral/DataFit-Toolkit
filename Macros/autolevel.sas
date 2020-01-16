/*========================================================================  
DataFit Toolkit - Autolevel macro
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


/*___________________________________________________________________
 |  MACRO:       AUTOLEVEL
 |
 |  JOB:         Data Quality
 |
 |  PROGRAMMER:  Mahmoud Azimaee
 |
 |  DATE:        April 2011
 |
 |  DESCRIPTION: This Macro gets the levels of Character variables
 |               in a dataset and list them. If there are too many
 |               then only first and last level will be shown. This
 |               is a intermediate macro and is called by VIMO Macro
 |
 |  PARAMETERS:  DS= Name of Dataset
 |
 |  EXAMPLE:     %AUTOLEVEL (health.MHCPL_SPsection_19922010);
 |
 |  Update:      May 2013 (Xiaoping Zhao)
 |               -compress special symbols in value field.
 |       
 |               Nov 2016, Mahmoud Azimaee
 |               - Major updates on all macros in order to make them compatible with SAS PC  
 |            
  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%MACRO AUTOLEVEL(data=CHARFREQ,
                 out=CLEVEL);

PROC SORT DATA=&data (WHERE=(VALUE^='')) OUT=CHARFREQ2;
        BY VARNAME;
RUN;

DATA CHARFREQ2;
        SET CHARFREQ2;
        BY VARNAME;
        LENGTH=LENGTH(TRIM(VALUE));
        RUN;

PROC FREQ DATA=CHARFREQ2 NOPRINT;
        TABLE VARNAME/OUT=NOBS(RENAME=(COUNT=NOBS) DROP=PERCENT) ;
RUN;

PROC SORT DATA=CHARFREQ2;
        BY VARNAME DESCENDING LENGTH;
RUN;

DATA CHARFREQ2;
        MERGE CHARFREQ2 NOBS;
        BY VARNAME;
RUN;


DATA CHARFREQ2;
        SET CHARFREQ2;
        BY VARNAME;
        RETAIN MAXLENGTH NOBS NO;
        IF FIRST.VARNAME THEN DO;
          NO=0;
          MAXLENGTH=LENGTH;
        END;
        NO=NO+1;
        IF NOBS * (MAXLENGTH + 2) > 55  THEN LONG=1; ELSE LONG=0;
        DROP LENGTH ;
        RUN;

        PROC SQL NOPRINT;
            SELECT DISTINCT(VARNAME) INTO: VARLIST SEPARATED ' '
            FROM CHARFREQ2;
        QUIT;

PROC SORT DATA=CHARFREQ2;
        BY VARNAME VALUE;
RUN;

        %LET DOI=%EVAL(%SYSFUNC(COUNTC(&VARLIST,' '))+1);

        %DO I=1 %TO &DOI;

                %LET VAR=%SCAN(&VARLIST,&I," ");
                %LET LONG=0;

                DATA TEMP;
                     SET CHARFREQ2 (WHERE=(VARNAME="&VAR"));
                     IF LONG & ^((NO=1) | (NOBS-NO=0)) THEN DELETE;

                     value=compress(value, '";'); *** update ***;
                     value=compress(value, "'");
                     value=compbl(value);

                RUN;

                PROC SQL NOPRINT;
                    SELECT LONG INTO: LONG
                    FROM TEMP
                    WHERE MONOTONIC()=1;
                QUIT;

                %GETNOBS (TEMP);

                %IF &NO=2 & &LONG=1 %THEN %DO;
                        PROC SQL NOPRINT;
                                SELECT VALUE INTO :LEVEL SEPARATED BY ", ... ,"
                                FROM TEMP;
                                QUIT;
                %END;
                %ELSE %DO;
                        PROC SQL NOPRINT;
                                SELECT VALUE INTO :LEVEL SEPARATED BY ", "
                                FROM TEMP;
                                QUIT;
                %END;

                %LET VAR&I=&VAR;
                %LET LEVEL&I=&LEVEL;
        %END;
                        DATA &out;
                                LENGTH VARNAME $32;
                                %DO J=1 %TO &DOI ;
                                        VARNAME = SYMGET("VAR&J");
                                        IF LENGTH(SYMGET("LEVEL&J")) > 50 THEN  LEVEL = SUBSTR(SYMGET("LEVEL&J"),1,35) || ', ...' ;
                                                ELSE LEVEL = SYMGET("LEVEL&J") ;
                                        OUTPUT;
                                %END;
                        RUN;

              PROC DATASETS LIBRARY=WORK;
                      DELETE CHARFREQ2 NOBS TEMP ;
                  QUIT;
                  RUN;

%MEND AUTOLEVEL;
