/*========================================================================  
DataFit Toolkit - Trend macro
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
  | MACRO:       TREND
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        April 2011
  |
  | DESCRIPTION: For a given table, this Macro perfoms a trend
  |              analysis over a specified time range. The results
  |              will be only in graphic formats.
  |              The Graph(s) will be shown on screen and also will
  |              be saved in PNG format in the given &PATH
  |
  | PARAMETERS:  DS= Name of SAS dataset
  |
  |              DSPREFIX = If DS is a prefix, then DSPREFIX should be ON
  |                         Default: OFF
  |
  |              STARTYR= Beginning year (1st part for fiscal, 4-digit)
  |
  |              ENDYR= Ending year (1st part for fiscal, 4-digit)
  |
  |              BYDATE= Desired Date variable (Must be SAS Date variable)
  |
  |              BYVAR= An optional categorical variable. If omitted
  |                     only one trend analysis will be done for all the
  |                     records in the dataset.
  |
  |              BYFMT= An optional Format for BYVAR if there exists
  |                     any.
  |
  |              TIME= Must be one of these values: FISCAL, MONTHLY, CALENDAR
  |                    (default value is FISCAL)
  |
  |              PATH = Specify a location for storing PNG format of the graph.
  |
  | EXAMPLES:    %TREND (DS=health.wrha_ccic_med_2003mar,
  |                      STARTYR=2003,
  |                      ENDYR=2010,
  |                      BYDATE=admit_dt,
  |                      BYVAR=HOSP,
  |                      BYFMT=$HOSPFMTL.);
  |                      PATH='~/DQ/');
  |
  |              %TREND (DS=nrs.admission,
  |                      startyr=2000,
  |                      endyr=2011,
  |                      bydate=admdate,
  |                      TIME=calendar,
  |                      path='~/bkup/DQ/NRS');
  |
  |              %TREND (DS=nrs.admission,
  |                      startyr=2000,
  |                      endyr=2011,
  |                      bydate=admdate,
  |                      path='~/bkup/DQ/NRS');
  |
  |              %TREND (DS=cihi.cihi,
  |                      dsprefix=on
  |                      startyr=2000,
  |                      endyr=2011,
  |                      bydate=ddate,
  |                      time=fiscal,
  |                      path='~/bkup/DQ/NRS');
  |
  |
  | UPDATES:     2014-05-15 (Nicholas Gnidziejko)
  |              - Output file name of graph is now <datasetname>_trend.png
  |
  |              2014-05-29 (Nicholas Gnidziejko)
  |              - New parameter: DSPREFIX  
  |              - Verify if directory provided in PATH parameter exists
  |              - Remove duplicate proc gplot code that was printing
  |                graph on screen in addition to the output png file
  |
  |             2015-04-15 (Gangamma Kalappa)	
  |             - Added code to save the default users settings and revert back to 
  |               it after trend macro completes the execution.In between the 
  |               execution ods listing is activated to ensure that trend image
  |               is dumped in desired location.
  |
  |             2015-06-09 (Sean Ji)	
  |             - Added legend; modified the title, footnotes and line size.
  | 
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |
  |             2015-12-07 (Sean Ji)	
  |             - Added code to let the parameter BYDATE can take DATETIME variable
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%Macro TREND(DS=,
             DSPREFIX=OFF,
             STARTYR=,
             ENDYR=,
             BYDATE=,
             BYVAR=_ALL_,
             BYFMT=,
             TIME=FISCAL,
             PATH=
             );

	/*15, April 2015 update*/
    proc optsave key='core\options';
    run;
    ods listing;
    ods graphics off;
    /*End of 15, April 2015 update*/
    
    %local eq;

    %LET TIME=%UPCASE(&TIME);

    %IF &TIME^=FISCAL %THEN %IF &TIME^=MONTHLY %THEN %IF &TIME^=CALENDAR %THEN %IF &TIME^=QUARTERLY %THEN%DO;

        %PUT ___________________________________________________________________;
        %PUT | ERROR: Wrong value for TIME: &TIME                               |;
        %PUT | You can only specify one of the follwoing values for the TIME    |;
        %PUT | parameter:                                                       |;
        %PUT | FISCAL, CALENDAR, MONTHLY, QUARTERLY                             |;
        %PUT | Macro stopped executing                                          |;
        %PUT ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯;

        %goto exit;
     %END;

    /*******************************************************************
       Verify that directory from PATH exists
    *******************************************************************/
    %if %sysfunc(fileexist(&PATH.)) = 0 %then %do;
        %PUT ___________________________________________________________________;
        %PUT | ERROR: The directory provided in the PATH parameter,;
        %PUT |        &PATH.; 
        %PUT |        does not exist.;
        %PUT |        Macro stopped executing;
        %PUT ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯;
         %abort;
    %end;    

    /*******************************************************************
       Combine yearly datasets when DSPREFIX=ON
    *******************************************************************/
    %let dsprefix = %upcase(&dsprefix.);

    /* Get &lib and &dsn */
    %if %upcase(&dsprefix) = OFF %then %do;
      %GETVARLIST (&DS);
    %end;
    %else %if %upcase(&dsprefix) = ON %then %do;
      %GETVARLIST (&DS.&STARTYR.);
    %end; 
    
    %if &dsprefix. = ON %then %do;
        /* Combine yearly datasets */
        data &lib._all;
         set 
          %do year=&startyr. %to &endyr.;
           &ds.&year. 
           %IF &BYVAR  = _ALL_ %THEN (keep=&BYDATE);
           %IF &BYVAR ^= _ALL_ %THEN (keep=&BYDATE &BYVAR);
          %end; 
         ;
        run;

        /* Define new dataset name */
        %let DS = &lib._all;
    %end;
      


    /**********************************************
      Find out the format for the &bydate variable
    ***********************************************/
    proc sql noprint;
       select 
         format into: bydatefmtindata
       from 
         dictionary.columns
       where 
         upcase(libname) = "%upcase(&lib)"
         and
         upcase(memname) = "%upcase(&dsn)"
         and
         upcase(name)    = "%upcase(&bydate)"
       ;
    quit; 



     data Data_Temp;
        %IF &BYVAR =_ALL_ %THEN set &DS (keep=&BYDATE);;
        %IF &BYVAR ^=_ALL_ %THEN set &DS (keep=&BYDATE &BYVAR);;
        %if %sysfunc(compress(&bydatefmtindata, ., d)) = DATETIME %then %do;
          &bydate = datepart(&bydate);
          format &bydate date9.;
        %end;
     run;

        %IF &TIME=FISCAL %THEN %DO;
            %fiscalyr(&STARTYR,&ENDYR) ;;
        %END;

        %IF &TIME=MONTHLY %THEN %DO;
            %monthly(&STARTYR,&ENDYR);;
        %END;

        %IF &TIME=CALENDAR %THEN %DO;
            %calendaryr(&STARTYR,&ENDYR);;
        %END;
        data Data_Temp;
                set Data_Temp;
                length trend_by $ 64  yr $ 11;
                %IF &TIME=FISCAL    %THEN yr=put(&BYDATE,fy.);;
                %IF &TIME=MONTHLY   %THEN yr=put(&BYDATE,monthly.);;
                %IF &TIME=CALENDAR  %THEN yr=put(&BYDATE,cy.);;
                %IF &TIME=QUARTERLY %THEN %DO;              
                      IF MONTH(&BYDATE) IN (1,2,3) THEN _q='1';
                         ELSE IF MONTH(&BYDATE) IN (4,5,6) THEN _q='2';
                           ELSE IF MONTH(&BYDATE) IN (7,8,9) THEN _q='3';
                              ELSE IF MONTH(&BYDATE) IN (10,11,12) THEN _q='4';
                     yr = COMPRESS(YEAR(&BYDATE)||'-Q' || _q );
                     IF SYMGETN('startyr') > YEAR(&BYDATE) OR YEAR(&BYDATE) > SYMGETN('endyr') THEN yr='Other Years';
                 %END;
                
                %IF &BYVAR =_ALL_ %THEN trend_by="&BYVAR";;
                %IF &BYVAR ^=_ALL_ & &BYFMT= %THEN trend_by=&BYVAR;;
                %IF &BYVAR ^=_ALL_ & &BYFMT^= %THEN trend_by=put(&BYVAR,&BYFMT);;

        run;

        proc freq data=Data_Temp noprint;
                table yr*trend_by / list out=trend_data sparse;
                run;

        data trend_data;
                set trend_data;
                by yr;
                if yr in ('Other Years', 'unknown' , '') then delete;
                else sup=0;
                if substr(yr,1,3)='JAN' then monthyr= substr(yr,4)||'01';
                if substr(yr,1,3)='FEB' then monthyr= substr(yr,4)||'02';
                if substr(yr,1,3)='MAR' then monthyr= substr(yr,4)||'03';
                if substr(yr,1,3)='APR' then monthyr= substr(yr,4)||'04';
                if substr(yr,1,3)='MAY' then monthyr= substr(yr,4)||'05';
                if substr(yr,1,3)='JUN' then monthyr= substr(yr,4)||'06';
                if substr(yr,1,3)='JUL' then monthyr= substr(yr,4)||'07';
                if substr(yr,1,3)='AUG' then monthyr= substr(yr,4)||'08';
                if substr(yr,1,3)='SEP' then monthyr= substr(yr,4)||'09';
                if substr(yr,1,3)='OCT' then monthyr= substr(yr,4)||'10';
                if substr(yr,1,3)='NOV' then monthyr= substr(yr,4)||'11';
                if substr(yr,1,3)='DEC' then monthyr= substr(yr,4)||'12';
                drop PERCENT;
                run;

        proc sort data=trend_data;
                %IF &TIME ^=MONTHLY %THEN by trend_by yr;;
                %IF &TIME  =MONTHLY %THEN by trend_by monthyr;;
                run;

        *** Do the transformations;
        data trend_data;
                set trend_data;
                %IF &TIME ^=MONTHLY %THEN by trend_by yr;;
                %IF &TIME  =MONTHLY %THEN by trend_by monthyr;;
                %IF &TIME ^=MONTHLY %THEN %DO;
                        retain firstyr;
                        time=input(substr(yr,1,4),4.);;
                        COUNT1=lag(COUNT);;
                        if first.trend_by then firstyr=time;;
                        time=time - firstyr + 1;;
                %END;
                if first.trend_by then time=0;
                time + 1;
                time2=time*time;
                logtime=log(time);
                sqrttime=sqrt(time);
                exptime=exp(time);
                inverstime=1/time;
                negexptime=exp(-time);
                run;

        *** Find the best Regression Model by Minimum RSME;
        proc reg data=trend_data outest=parms noprint;
                Linear: model COUNT=Time / EDF ;
                Quatratic: model COUNT=Time2 / EDF ;
                Exponential: model COUNT=exptime / EDF ;
                Logaritmic: model COUNT=logtime / EDF ;
                SQRT: model COUNT=sqrttime / EDF ;
                Inverse: model COUNT=inverstime / EDF ;
                Neg_Exponential: model COUNT=negexptime / EDF ;
                by trend_by;
        run;

        Proc means data=parms noprint;
                var _RMSE_ ;
                by trend_by;
                output out=RMSE (keep=trend_by RMSE) MIN=RMSE;
                run;

        data parms;
                merge parms RMSE;
                by trend_by;
                if _RMSE_ = RMSE;
                rename _RSQ_ = RSQ _MODEL_ = Model;
                keep trend_by _MODEL_ RMSE _RSQ_ ;
                run;

        data trend_data;
                merge trend_data parms;
                by trend_by;
                if time=1 then COUNT1=.;
                if count=count1 & COUNT ^in (0, 5.999) then same=1;
                        else same=0;
                run;

        ***Fit the best model for each subset of data and save the regression coefficients and Studentized residuals;
        data res_lin res_quad res_exp res_log res_sqrt res_inv res_neg;
                length COUNT 8. trend_by $ 64.;
                run;
        proc reg data=trend_data outest=parm_lin noprint;
                Linear: model COUNT=Time;
                by trend_by;
                output out=res_lin RSTUDENT=STR;
                format time time.;
                where model='Linear';
        run;

        proc reg data=trend_data outest=parm_quad noprint;
                Quatratic: model COUNT=Time2;
                by trend_by;
                output out=res_quad RSTUDENT=STR;
                format time time.;
                where model='Quatratic';
        run;

        proc reg data=trend_data outest=parm_exp noprint;
                Exponential: model COUNT=exptime;
                by trend_by;
                output out=res_exp RSTUDENT=STR;
                format time time.;
                where model='Exponential';
        run;

        proc reg data=trend_data outest=parm_log noprint;
                Logaritmic: model COUNT=logtime ;
                by trend_by;
                output out=res_log RSTUDENT=STR;
                format time time.;
                where model='Logaritmic';
        run;

        proc reg data=trend_data outest=parm_sqrt noprint;
                SQRT: model COUNT=sqrttime ;
                by trend_by;
                output out=res_sqrt RSTUDENT=STR;
                format time time.;
                where model='SQRT';
        run;

        proc reg data=trend_data outest=parm_inv noprint;
                Inverse: model COUNT=inverstime ;
                by trend_by;
                output out=res_inv RSTUDENT=STR;
                format time time.;
                where model='Inverse';
        run;

        proc reg data=trend_data outest=parm_neg noprint;
                Neg_Exponential: model COUNT=negexptime ;
                by trend_by;
                output out=res_neg RSTUDENT=STR;
                format time time.;
                where model='Neg_Exponential';
        run;

        %LET parm_all=;
        %GETNOBS(parm_lin);  %if &NO ^=0 %then %LET parm_all=&parm_all parm_lin;
        %GETNOBS(parm_quad); %if &NO ^=0 %then %LET parm_all=&parm_all parm_quad;
        %GETNOBS(parm_exp);  %if &NO ^=0 %then %LET parm_all=&parm_all parm_exp;
        %GETNOBS(parm_log);  %if &NO ^=0 %then %LET parm_all=&parm_all parm_log;
        %GETNOBS(parm_sqrt); %if &NO ^=0 %then %LET parm_all=&parm_all parm_sqrt;
        %GETNOBS(parm_inv);  %if &NO ^=0 %then %LET parm_all=&parm_all parm_inv;
        %GETNOBS(parm_neg);  %if &NO ^=0 %then %LET parm_all=&parm_all parm_neg;

        data parm_all;
                set &parm_all;
                by trend_by;
                array beta{7} time time2 exptime logtime sqrttime inverstime negexptime;
                do i=1 to 7;
                        if  beta{i} ^=. then Beta1=beta{i};
                end;
                keep trend_by intercept beta1;
                run;
        data parms;
                merge parms parm_all;
                by trend_by;
                run;
        data trend_data;
                merge trend_data parms;
                by trend_by;
                if Model='Linear' then yhat=intercept + beta1*time;
                if Model='Quatratic' then yhat=intercept + beta1*time2;
                if Model='Exponential' then yhat=intercept + beta1*exptime;
                if Model='Logaritmic' then yhat=intercept + beta1*logtime;
                if Model='SQRT' then yhat=intercept + beta1*sqrttime;
                if Model='Inverse' then yhat=intercept + beta1*inverstime;
                if Model='Neg_Exponential' then yhat=intercept + beta1*negexptime;
                run;

        %LET res_all=;
        %GETNOBS( res_lin);  %if &NO >1 %then %LET  res_all=&res_all res_lin;
        %GETNOBS( res_quad); %if &NO >1 %then %LET  res_all=&res_all res_quad;
        %GETNOBS( res_exp);  %if &NO >1 %then %LET  res_all=&res_all res_exp;
        %GETNOBS( res_log);  %if &NO >1 %then %LET  res_all=&res_all res_log;
        %GETNOBS( res_sqrt); %if &NO >1 %then %LET  res_all=&res_all res_sqrt;
        %GETNOBS( res_inv);  %if &NO >1 %then %LET  res_all=&res_all res_inv;
        %GETNOBS( res_neg);  %if &NO >1 %then %LET  res_all=&res_all res_neg;

        data res_all;
                set &res_all;
                by trend_by;
                if YR^='';
                keep YR trend_by STR monthyr;
                run;
        proc freq data=trend_data noprint;
                table yr / list out=t;
                run;
        %GETNOBS(t);
        data t;
                set t;
                call SYMPUT('t',tinv(.95,%EVAL(&NO-2-1)));
                run;
        data trend_data;
                length model2 $30 trend_by2 $64;
                merge trend_data res_all;
                %IF &TIME ^=MONTHLY %THEN by trend_by yr;;
                %IF &TIME  =MONTHLY %THEN by trend_by monthyr;;
                t=SYMGETN('t');
                label t='t(.95,n-p-1)';
                if (t < STR)  | (STR < -t) then outlier=1;
                        else outlier=0;
                if Model='Linear'          then model2='Y=Beta0 + Beta1*X      ';
                if Model='Quatratic'       then model2='Y=Beta0 + Beta1*X^2    ';
                if Model='Exponential'     then model2='Y=Beta0 + Beta1*exp(X) ';
                if Model='Logaritmic'      then model2='Y=Beta0 + Beta1*log(X) ';
                if Model='SQRT'            then model2='Y=Beta0 + Beta1*SQRT(X)';
                if Model='Inverse'         then model2='Y=Beta0 + Beta1*(1/X)  ';
                if Model='Neg_Exponential' then model2='Y=Beta0 + Beta1*Exp(-X)';
                if trend_by='_ALL_' then trend_by2='All Records';
                else trend_by2=trend_by;
                if 0 < COUNT < 6 then do;
                        COUNT=3;
                        sup=1;
                        end;
                Lable trend_by2='By Variable';
                run;

        data graphlabel(keep=function hsys xsys ysys xc y text color position size trend_by trend_by2);
                set trend_data;
                by trend_by2;
                * Define annotate variable attributes;
                length color function $8 text $30;
                retain  function 'symbol'
                                hsys '3'
                                xsys ysys '2'
                                color 'red'
                                position '2'
                                size 4;
                if outlier=1 then do;
                        * Create a label;
                        text = 'dot';
                        %IF &TIME ^=MONTHLY %THEN xc=yr;;
                        %IF &TIME  =MONTHLY %THEN xc=monthyr;;
                        y=count;
                        output graphlabel;
                        end;
                run;


        data graphlabel2(keep=function hsys xsys ysys xc y text color position size trend_by trend_by2);
                set trend_data;
                %IF &TIME ^=MONTHLY %THEN by trend_by2 yr;;
                %IF &TIME  =MONTHLY %THEN by trend_by2 monthyr;;
                * Define annotate variable attributes;
                length color function $8 text $30;
                retain  function 'label'
                                hsys 'D'
                                xsys ysys '2'
                                color 'vibg'
                                position '3'
                                size 8;
                %IF &TIME ^=MONTHLY %THEN if last.trend_by2 & last.yr then do;;
                %IF &TIME  =MONTHLY %THEN if last.trend_by2 & last.monthyr then do;;
                        * Create a label;
                        text = model2;
                        %IF &TIME ^=MONTHLY %THEN xc=yr;;
                        %IF &TIME  =MONTHLY %THEN xc=monthyr;;
                        y=yhat;
                        output graphlabel2;
                        end;
                run;

        data graphlabel3(keep=function hsys xsys ysys xc y text color position size trend_by trend_by2);
                set trend_data;
                %IF &TIME ^=MONTHLY %THEN by trend_by2 yr;;
                %IF &TIME  =MONTHLY %THEN by trend_by2 monthyr;;
                * Define annotate variable attributes;
                length color function $8 text $30;
                retain  function 'symbol'
                                hsys '3'
                                xsys ysys '2'
                                color 'green'
                                position '2'
                                size 5;
                if sup=1 then do;
                        * Create a label;
                        text = 'circle';
                        %IF &TIME ^=MONTHLY %THEN xc=yr;;
                        %IF &TIME  =MONTHLY %THEN xc=monthyr;;
                        y=count;
                        output graphlabel3;
                        end;
                run;
        data graphlabel4(keep=function hsys xsys ysys xc y text color position size trend_by trend_by2);
                set trend_data;
                %IF &TIME ^=MONTHLY %THEN by trend_by2 yr;;
                %IF &TIME  =MONTHLY %THEN by trend_by2 monthyr;;
                * Define annotate variable attributes;
                length color function $8 text $30;
                retain  function 'symbol'
                                hsys '3'
                                xsys ysys '2'
                                color 'orange'
                                position '2'
                                size 4;
                if same=1 then do;
                        * Create a label;
                        text = 'dot';
                        %IF &TIME ^=MONTHLY %THEN xc=yr;;
                        %IF &TIME  =MONTHLY %THEN xc=monthyr;;
                        y=count;
                        output graphlabel4;
                        end;
                run;

        data graphlabel;
                set graphlabel graphlabel2 graphlabel3 graphlabel4;
                by trend_by2;
                run;
        
        *get the text string using in legend;
        proc sql noprint;
            select strip(text) into :eq
            from   graphlabel
            where  color='vibg' and function='label'
            ;
        quit;

        goptions reset=all noborder cback=white hsize=600pt vsize=400pt gunit=pt;
        symbol1 i=join l=1  w=1.8 v=dot color='blue' h=10pt pointlabel=none;
        symbol2 i=join l=20 w=1.8 v=dot c=vibg h=.1pt pointlabel=none ;

        title1 f=zapfb h=12pt c=blue "Trend Analysis for Dataset: %upcase(&DS)";
        title2 f=zapfb h=10pt "Date Variable: &BYDATE, By Variable: &BYVAR";

        footnote1 justify=c move=(-230, 5) font='monotype sorts /bold' height=10pt c=red "6c"x
                  font='Thorndale AMT/bold' c=black "  Significant outliers";
        footnote2 justify=c move=(190, 5)font='monotype sorts/bold' height=10pt c=orange "6c"x
                  font='Thorndale AMT/bold' c=black "  Identical Subsequent frequencies";
        footnote3 justify=c move=(360, 5) font='monotype sorts/bold' height=10pt c=green  "6d"x 
                  font='Thorndale AMT/bold' c=black "  Suppressed small frequencies (between 0 to 6)";
        
        
        %IF &TIME =FISCAL %THEN 
            axis1  minor=none value=(h=10pt angle=90) offset=(10,100) label=('Fiscal Year');;
        %IF &TIME =CALENDAR %THEN
            axis1  minor=none value=(h=10pt angle=90) offset=(10,100) label=('Calendar Year');;
        %IF &TIME =MONTHLY %THEN
            axis1  minor=none value=(h=10pt) offset=(10,100) label=('Month');;
        %IF &TIME =QUARTERLY %THEN
            axis1  minor=none value=(h=10pt angle=90) offset=(10,100) label=('Quarter');;

        axis2 minor=none offset=(0,20) label=('Frequency' justify=right );
        legend1 label=(font="Thorndale AMT/bold" height=10pt color='black' 'Trend Line') value=("Observed Trend" "Predicted Trend:  %sysfunc(strip(&eq.))");
        
        *** Re-Plotting for output PNG format;
        * Get dataset name without libname;
        %local dsn;
        %if %sysfunc(find(&DS.,%str(.))) > 0 %then %let DSN = %scan(&DS.,2,%str(.));
        %else %let DSN = &DS.;      
        %LET PATH=%SYSFUNC(CAT("&PATH"));
        filename graphout &PATH;
        goptions device=png target=png gsfname=graphout gunit=pt;

        proc GPLOT data=trend_data;
				format COUNT comma12.;
                %IF &TIME ^=MONTHLY %THEN
                plot COUNT*yr yhat*yr / overlay
                                        frame
                                        haxis=axis1
                                        vaxis=axis2
                                        cframe=gwh
                                        annotate=graphlabel
                                        name="&DSN._trend"
                                        legend=legend1;;
                %IF &TIME =MONTHLY %THEN
                plot COUNT*monthyr yhat*monthyr / overlay
                                                  frame
                                                  haxis=axis1
                                                  vaxis=axis2
                                                  cframe=gwh
                                                  annotate=graphlabel
                                                  name="&DSN._trend"
                                                  legend=legend1;;
                by trend_by2;
                %IF &BYFMT ^='' %THEN %DO;
                        format trend_by2 &BYFMT;
                        %END;
        run;
        quit;

        goptions reset=all;
        
        proc datasets lib=work nolist nowarn;
              delete data_temp graphlabel graphlabel2-graphlabel4 
					 parms parm_all parm_lin parm_exp parm_inv parm_log  parm_neg parm_quad parm_sqrt
					 res_all res_exp res_inv res_lin res_log res_negres_quad res_sqrt res_neg res_quad
					 rmse t trend_data &lib._all;
        run;
        quit;
        
        ods graphics on;
    	ods listing close;

    /* Clean the global macros variables */
    %symdel NVARLIST CVARLIST LIB DSN;

		proc optload key='core\options';
   		run;

%EXIT:
%MEND TREND;
