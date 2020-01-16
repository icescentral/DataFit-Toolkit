/*========================================================================  
DataFit Toolkit - Monthly macro
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
  | MACRO:       MONTHLY
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        October 2011
  |
  | DESCRIPTION: This Macro creates a monthly based format to be
  |              used on a SAS Date variable. The format will be available
  |              under Work format Catalog.It will be a numeric format
  |              and called monthly.
  |
  | PARAMETERS:  STARTYR= Fisrt part of the starting calendar year
  |
  |              ENDYR= Fisrt part of the ending calendar year
  |
  | EXAMPLE:     %monthly(1992,2009);
  |
  | UPDATE:
  |              October 2014, Gangamma Kalappa
  |              - Update to fix issue related to monthly format created
  |                  Example:
  |                        (Before the update January 2012 was represented as
  |                         Start value='01Jan2012'd
  |                         and End value='01Feb2012'd) which resulted in
  |                         including a day from the following year when format for
  |                         month of December was created.
  |               This led to different total linkage rate for same dataset
  |               when linkability was run with time option as monthly and calendar
  |               year. Linkage rate calculated should be the same for given time period;
  |               either its calculated quarterly or monthly
  |               or per calendar year.
  |
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

**********************************************************************;


%Macro monthly(startyr,endyr);



        data month;
                month='Jan'; nextmonth='Feb'; m=1; output;
                month='Feb'; nextmonth='Mar'; m=2; output;
                month='Mar'; nextmonth='Apr'; m=3; output;
                month='Apr'; nextmonth='May'; m=4; output;
                month='May'; nextmonth='Jun'; m=5; output;
                month='Jun'; nextmonth='Jul'; m=6; output;
                month='Jul'; nextmonth='Aug'; m=7; output;
                month='Aug'; nextmonth='Sep'; m=8; output;
                month='Sep'; nextmonth='Oct'; m=9; output;
                month='Oct'; nextmonth='Nov'; m=10; output;
                month='Nov'; nextmonth='Dec'; m=11; output;
                month='Dec'; nextmonth='Jan'; m=12; output;
        run;
        data month;
                set month;
                fmtname ='monthly';
                startnum=SYMGETN('startyr');
                endnum=SYMGETN('endyr');
                yrs=endnum - startnum;
                do year=startnum to endnum;
                        StartChar='01' || month || put(year,$4.);
                        EndChar  ='01' || nextmonth || put(year,$4.);
                        Label=  upcase(month)||put(year,$4.);
                        if month='Dec' then do;
                                EndChar  ='01' || nextmonth || put(year+1,$4.);
                        end;
                        Start=input(StartChar,date9.);

                        End=input(EndChar,date9.)-1;

                        output;
                end;
        run;

        proc sort data=month;
                by year m;
        run;

        data month;
                length label $ 11 ;
                set month end=eof;
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
       proc format cntlin=month;
                run;

        proc datasets library=work ;
               delete month;
        run;
        quit;

%Mend monthly;
