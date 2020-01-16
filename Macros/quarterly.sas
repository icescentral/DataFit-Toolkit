/*========================================================================  
DataFit Toolkit - Quarterly macro
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
  | MACRO:       QUARTERLY
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Gangamma Kalappa
  |
  | DATE:        October 2014
  |
  | DESCRIPTION: This Macro creates a quarterly format to be
  |              used on a SAS Date variable. The format will be available
  |              under Work format Catalog.It will be a numeric format
  |              and called quarterly.
  |
  | PARAMETERS:  STARTYR= Fisrt part of the starting calendar year
  |
  |              ENDYR= Fisrt part of the ending calendar year
  |
  | EXAMPLE:     %quarterly(2000,2014)
  | 
  | UPDATES:   
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

**********************************************************************;

%Macro quarterly(startyr,endyr);

        data quarter;
                quarter='Jan';  nextquarter='Apr';      q='1'; output;
                quarter='Apr';  nextquarter='Jul';      q='2'; output;
                quarter='Jul';  nextquarter='Oct';      q='3'; output;
                quarter='Oct';  nextquarter='Jan';      q='4'; output;
        run;

        data quarter;
                set quarter;
                fmtname ='quarterly';
                startnum=SYMGETN('startyr');
                endnum=SYMGETN('endyr');
                yrs=endnum - startnum;
                do year=startnum to endnum;
                        StartChar= '01' || quarter || put(year,$4.);
                        EndChar  = '01' || nextquarter || put(year,$4.);
                        Label=  put(year,$4.)|| '-Q' || q;
                        if quarter='Oct' then do;
                                EndChar  = '01' || nextquarter || put(year+1,$4.) ;
                        end;
                        Start=input(StartChar,date9.);
                        End=input(EndChar,date9.)-1;
                        output;
                end;
        run;

        proc sort data=quarter;
                by year q;
        run;

        data quarter;
                length label $ 11 ;
                set quarter end=eof;
                output;
            if eof then do;
                        HLO='O';
                        label='Other';
                        start=0;
                        end=0;
                        output;
                end;
                keep fmtname start end label HLO;
        run;
        proc format lib=work cntlin=quarter;
        run;

        proc datasets library=work ;
                delete quarter;
        run;
        quit;

%Mend quarterly;
