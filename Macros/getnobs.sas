/*========================================================================  
DataFit Toolkit - GentNOBS macro
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
  | MACRO:       GETNOBS
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        April 2011
  |
  | DESCRIPTION: This macro returns Number of Observations in the
  |              given dataset through the macro variable NO. It is
  |              an intermediate macro and is used in many other
  |              DQ macros
  |
  | PARAMETERS:  DS= Name of Dataset
  |
  | EXAMPLE:     %GETNOBS (health.MHCPL_SPsection_19922010);
  |
  | Update:      June 2013 (Xiaoping Zhao)
  |              - change nobs to nlobs from dictionary.tables to
  |                get correct observation counts
  |              - create macro variable NO in data step to avoid
  |                observation count in scientific notion when
  |                it is really big.
  |       
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
    ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%MACRO GETNOBS(DS) ;
     %GLOBAL NO;
     %LET NO=;
     %LET DS=%UPCASE(&DS);
     %IF %INDEX(&DS,.)=0 %THEN %LET _LIBNAME=WORK;
     %ELSE %DO;
        %LET _LIBNAME=%SCAN(&DS,1,'.');
        %LET DS=%SCAN(&DS,2,'.');
     %END;

     PROC SQL NOPRINT;
       create table cnt as select nlobs from dictionary.tables
       where libname= "&_LIBNAME" AND MEMNAME="&DS";
     quit;

     data _null_;
       set cnt;

       call symput ('NO', nlobs);
     run;

     proc delete data=cnt; run;
%MEND GETNOBS;
