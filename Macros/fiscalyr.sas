/*========================================================================  
DataFit Toolkit - FiscalYR macro
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
  |MACRO:       FISCALYR
  |
  |JOB:         Data Quality
  |
  |PROGRAMMER:  Mahmoud Azimaee
  |
  |DATE:        April 2011
  |
  |DESCRIPTION: This Macro creates a fiscal year format to be used
  |             on a SAS Date variable. The format will be available
  |             under Work format Catalog. It will be a numeric format
  |             and called fy.
  |
  |PARAMETERS:  STARTYR= Fisrt part of the starting fiscal year
  |
  |             ENDYR= Fisrt part of the ending fiscal year
  |
  |EXAMPLE:     %fiscalyr(1992,2009);
  |
  |UPDATES:     2014-05-28 (Nicholas Gnidziejko)
  |             - Corrected issue where lcl and ucl were unnecessarily
  |               being converted to numeric variables
  |       
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%Macro fiscalyr(startyr,endyr);

        data fiscalyr;
         format label $11.;
                fmtname ='fy';
                startChar='01Apr';
                middle='31Mar';
                startnum=SYMGETN('startyr');
                endnum=SYMGETN('endyr');
                yrs=endnum - startnum;
                do i=0 to yrs;
                        lcl=startnum + i;
                        ucl=lcl + 1;
                        valueChar=cats(startChar,lcl);
                        ENDChar=cats(middle,ucl);
                        Start=input(valueChar,date9.);
                        End=input(endChar,date9.);
                        LABEL= cats(lcl,"/",substr(left(ucl),3,2));
                        output;
                end;
                run;

                data fiscalyr;
                        length label $ 11 ;
                        set fiscalyr end=eof;
                        output;
                    if eof then do;
                                HLO='O';
                                label='Other Years';
                                start=0;
                                end=0;
                                output;
                        end;
                        keep fmtname start end label HLO;
                run;

                proc format cntlin=fiscalyr;
                        run;

                proc datasets library=work ;
                        delete fiscalyr;
                run;
                quit;

%Mend fiscalyr;
