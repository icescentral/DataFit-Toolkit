/*========================================================================  
DataFit Toolkit - CharFreq macro
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
 |  MACRO:        CHARFREQ
 |
 |  JOB:         Data Quality
 |
 |  PROGRAMMER:  Mahmoud Azimaee
 |
 |  DATE:        September 2012
 |
 |  DESCRIPTION: This Macro creates a SAS datasets called charfreq.sas7bdat
 |               in the work directory. It contains frequnecies for each
 |               level of all character variables (except for &ID and
 |               &EXCLUDEFREQ variables defined in %VIMO). It also contains
 |               number of missing values for character variables. This dataset
 |               is used in other DQ macros such as %VIMO, %INVALID, ...
 |
 |
 |  PARAMETERS:  DS= Name of Dataset
 |
 |  EXAMPLE:     %CHARFREQ (health.MHCPL_SPsection_19922010);
 |       
 |              Nov 2016, Mahmoud Azimaee
 |              - Major updates on all macros in order to make them compatible with SAS PC  
 |				August2,2017, Gangamma Kalappa
 | 				- Removed compress option from proc sql as it was resulting in multiple entries in VIMO html 
 | 					when the value of variable is just '
 |				  If the program throws error or does not create desired result please ensure to bring back compress option
 |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%MACRO CHARFREQ (DS=);
options minoperator;

        %LET VARN=;
        %GETVARLIST(&DS);
        %LET VARN=%SYSFUNC(COUNTC(&CVARLIST,' '));
        %LET VARN=%EVAL(&VARN+1);
        %LET DOI=%EVAL(%SYSFUNC(COUNTC(&CVARLIST,' '))+1);

        %DO I=1 %TO &DOI;
                %LET VAR=%SCAN(&CVARLIST,&I," ");
                %IF &VAR in &IDVARS %THEN %DO;
                proc sql;
                      create table FREQ&I as
                      select put(strip(compress(&VAR,"'")), $50.) as VALUE ,
                      NMISS(&VAR) as MISSING
                      from &LIB..&DSN
                      where &VAR is MISSING
                      group by &VAR;
                   quit;

                   %GETNOBS(FREQ&I);
                   DATA FREQ&I;
                       %IF &NO^=0 %THEN SET FREQ&I;;
                       %IF &NO=0 %THEN %do;
                        MISSING=0;; 
                        length value $50;
                        value=' ';
                       %end;
                       length VARNAME $32;
                       VARNAME=SYMGETC('VAR');
                   RUN;
                %END;
                %ELSE %DO;
				  /*August2,2017 Update Start*/
                  /*proc sql;
                      create table FREQ&I as
                      select put(strip(compress(&VAR,"'")), $50.) as VALUE ,
                             count(&VAR) as Count,
                             NMISS (&VAR) AS MISSING
                      from &LIB..&DSN
                      group by (&VAR)
                      order by VALUE;
                  quit;*/
                  proc sql;
                      create table FREQ&I as
                      select put(strip(&VAR), $50.) as VALUE ,
                             count(&VAR) as Count,
                             NMISS (&VAR) AS MISSING
                      from &LIB..&DSN
                      group by (&VAR)
                      order by VALUE;
                  quit;
				  /*August2,2017 Update End*/
                  DATA FREQ&I;
                     SET FREQ&I;
                     length VARNAME $32;
                     VARNAME=SYMGETC('VAR');
                  RUN;
               %END;
         %END;

         Data CHARFREQ;
                set FREQ1 - FREQ&DOI ;
                VALUE=STRIP(VALUE);
                VARNAME=UPCASE(VARNAME);
         RUN;

         PROC SORT DATA=CHARFREQ;
            BY VARNAME;
         RUN;

         PROC DATASETS LIBRARY=WORK;
                 DELETE FREQ1 - FREQ&DOI;
             QUIT;
             RUN;

 %MEND CHARFREQ;
