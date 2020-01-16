/*========================================================================  
DataFit Toolkit - Outlier macro
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
  | MACRO:       OUTLIER
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        April 2011
  |
  | DESCRIPTION: This is an intermediate macro and is called by
  |              VIMO macro. %OUTLIER Identifies outliers among all
  |              numerci variables and create a temporary SAS dataset
  |              called "Outlier" containing number of outliers for each
  |              numeric variable to be used by %VIMO.
  |
  | PARAMETERS:  DS= Name of Dataset
  |
  | EXAMPLE:     %GETVARLIST (health.MHCPL_SPsection_19922010);
  |
  | Update:      May 2013 (Xiaoping Zhao)
  |              - exclude numerical variables with format from
  |                computation. Will create a frequency table for
  |                each of these variables.
  |
  |              17 Oct, 2014 (Gangamma Kalappa)
  |              - exclude TIME variables from being read into
  |                content_N dataset and from computation. Frequency table
  |                for each TIME variable would be created .
  |
  |              March 2015 (Sean Ji)
  |              - add option validvarname=v7;
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
%MACRO OUTLIER(DS);

	   %local validvarname;
       %let validvarname=%sysfunc(getoption(validvarname, keyword));
       options validvarname=v7;

       %LET VARN=%SYSFUNC(COUNTC(&NVARLIST_OUTLIER,' '));
       %LET VARN=%EVAL(&VARN+1);

       data content_N;
                set contents (where=(type=1 & format ^in ('YYMMDDD' , 'DATE' , 'DATETIME', 'YYMMDD', 'TIME')
                                   %if %length(&qnumvarfmtlist) >0 %then %do;
                                      and upcase(varname) not in (&qnumvarfmtlist) /** update: exclude num vars with format**/
                                   %end;
                                    )
                             );

                I + 1;
                keep VARNAME I;
                run;

        proc means data=&LIB..&DSN noprint qmethod=p2;
                var &NVARLIST_OUTLIER;
                output out=q1 (drop= _TYPE_ _FREQ_ )
                           q1 = /autoname;
        run;

        proc means data=&LIB..&DSN noprint qmethod=p2;
                var &NVARLIST_OUTLIER;
                output out=q3 (drop= _TYPE_ _FREQ_ )
                           q3=
                                  /autoname;
        run;

        proc means data=&LIB..&DSN noprint qmethod=p2;
                var &NVARLIST_OUTLIER;
                output out=qrange (drop= _TYPE_ _FREQ_ )
                           qrange= /autoname;
        run;

        proc transpose data=q1 out=q1; run;
        proc transpose data=q3 out=q3; run;
        proc transpose data=qrange out=qrange; run;

      data q1;
         set q1;
         I= _n_ ;
         rename COL1=q1;
         drop _LABEL_ _NAME_;
      run;

      data q3;
         set q3;
         I= _n_ ;
         rename COL1=q3;
         drop _LABEL_ _NAME_;
      run;

      data qrange;
         set qrange;
         I= _n_ ;
         rename COL1=qrange;
         drop _LABEL_ _NAME_ ;
      run;

      data content_n;
          merge content_n q1 q3 qrange;
          by I;
      run;

      /* Add MIN and MAX */
      PROC SORT DATA=CONTENT_N;
         BY VARNAME;
      RUN;

      DATA CONTENT_N;
         MERGE CONTENT_N (IN=IN_CONTENT) NVOUT (KEEP=VARNAME MIN MAX);
         BY VARNAME;
         IF IN_CONTENT;
      RUN;


      data outliers;
      run;

      %LET DS_DEL=;
      %LET VARS=;
      %DO I=1 %TO &VARN ;
              %LET VAR= ;
              %LET Q1=;
              %LET Q3=;
              %LET QRANGE=;
              %LET MIN=;
              %LET MAX=;

               PROC SQL NOPRINT;
                   SELECT VARNAME   INTO: VAR
                   FROM CONTENT_N
                   WHERE I = &I;

                   SELECT Q1 INTO: Q1
                   FROM CONTENT_N
                   WHERE I = &I;

                   SELECT Q3 INTO: Q3
                   FROM CONTENT_N
                   WHERE I = &I;

                   SELECT QRANGE INTO: QRANGE
                   FROM CONTENT_N
                   WHERE I = &I;

                   SELECT MIN INTO: MIN
                   FROM CONTENT_N
                   WHERE I = &I;

                   SELECT MAX INTO: MAX
                   FROM CONTENT_N
                   WHERE I = &I;
               QUIT;

               %LET DS_DEL=&DS_DEL &var ;
               data &var;
                    set &LIB..&DSN (keep=&VAR);
                    L= SYMGETN('q1') - 2.5*SYMGETN('qrange');
                    U= SYMGETN('q3') + 2.5*SYMGETN('qrange');
                    Q1= SYMGETN('q1');
                    Q3= SYMGETN('q3');
                    MIN= SYMGETN ('MIN');
                    MAX= SYMGETN ('MAX');
                    QRANGE=SYMGETN('qrange');
                    /*Note that QMETHOD=P2 then Q1, Q2, QRANGE are approximate */
                    IF L < MIN THEN L=MIN;
                    IF U > MAX THEN U=MAX;
                    if not missing(&VAR) & ( &VAR < L  or  &VAR > U ) then &var=1; else &var=0;
                    if U=L then &var=0;
                    keep &var ;
                run;
                %put &VAR &q1 &q3 &qrange;
                proc means data=&var noprint;
                        output out=outlier sum=&VAR;
                        run;
                Data outliers;
                    set outliers outlier;
                run;
                %LET VARS=&VARS &var;
      %END;
      data outliers;
            set outliers;
            drop _TYPE_ _FREQ_ ;
      run;
      proc means data=outliers noprint;
            output out=outlier sum=;
      run;
      data outlier;
           set outlier;
           drop _TYPE_ _FREQ_ ;
      run;

      proc transpose data=outlier out=outlier;
      run;
      data outlier;
        length _NAME_ $32. ;
        set outlier;
        _NAME_=UPCASE(_NAME_);
        rename _NAME_ = VARNAME COL1=Outlier_n;
        label _NAME_='Variable Name';
      run;

      proc datasets library=work ;
             delete &DS_DEL outliers content_n;
      run;
      quit;

      proc sort data=outlier;
           by varname;
      run;

      /****************************************************************
        restore the default validvarname option
      *****************************************************************/
      options &validvarname;

%MEND OUTLIER;
