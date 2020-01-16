/*========================================================================  
DataFit Toolkit - GetVarList macro
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
  | MACRO:       GETVARLIST
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        April 2011
  |
  | DESCRIPTION: This is an intermediate macro and is used in many
  |              other DQ macros. For a given dataset this Macro
  |              creates two macro variables containing a list of
  |              all character and numeric variables separated by
  |              a blank: NVARLIST & CVARLIST . %GETVARLIST also
  |              separates dataset name and library name and returns
  |              them in &DSN and &LIB .
  |
  | PARAMETERS:  DS= Name of Dataset
  |
  | EXAMPLE:     %GETVARLIST (health.MHCPL_SPsection_19922010);
  |       
  | Updates:    
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%MACRO GETVARLIST(DS);

        /* Initialize macro variables to null */
   %GLOBAL NVARLIST CVARLIST LIB DSN;
   %LET LIB = ;
   %LET DSN = ;
   %LET NVARLIST=;
   %LET CVARLIST=;

        /* Single level data set name */
   %IF %INDEX(&DS,.) = 0 %THEN %DO;
      %LET LIB = WORK;
      %LET DSN = %UPCASE(&DS);
   %END;

   /* Two level data set name */
   %ELSE %DO;
      %LET LIB = %UPCASE(%SCAN(&DS,1,"."));
      %LET DSN = %UPCASE(%SCAN(&DS,2,"."));
   %END;

   /* Note: it is important for the libname and Data set name to be in upper case
   * Get list of numeric variables  */
   PROC SQL NOPRINT;
      SELECT NAME INTO :NVARLIST SEPARATED BY " "
      FROM DICTIONARY.COLUMNS
      WHERE LIBNAME = "&LIB" AND MEMNAME = "&DSN" AND TYPE = "num";

   /* Get list of character variables */
   SELECT NAME INTO :CVARLIST SEPARATED BY " "
      FROM DICTIONARY.COLUMNS
      WHERE LIBNAME = "&LIB" AND MEMNAME = "&DSN" AND TYPE = "char";
   QUIT;

%LET NVARLIST=%UPCASE(&NVARLIST);
%LET CVARLIST=%UPCASE(&CVARLIST);

%MEND GETVARLIST;
