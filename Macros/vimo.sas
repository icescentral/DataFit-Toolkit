/*========================================================================  
DataFit Toolkit - VIMO macro
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

/*__________________________________________________________________________________
  | MACRO:       VIMO
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        April 2011
  |
  | DESCRIPTION: For a given SAS dataset, this Macro generates a VIMO
  |              Table as it has been described in MCHP Data Quality
  |              framework. It will be in HTML format and saved in the
  |              given &PATH under name of [Dataset name]_VIMO.html
  |              There will be a an equivalent SAS dataset in Work
  |              library called "VIMO"
  |
  | PARAMETERS:  DS= Name of Dataset
  |
  |              INVALIDS= Option to turn Invalid checks on or off
  |              (Default value=ON)
  |
  |              PATH= Location for saving the HTML VIMO report
  |
  |              POSTALS= List of variables containing postal codes for
  |                       validation, separated by blank.
  |
  |              FMTLIB= SAS library name(s) containing the format cataloges
  |                      (default is FORMATS)
  |
  |              METALIB= SAS library name containing METADATA
  |                       (Default is Meta)
  |
  |              FREQ= An option for turning ON/OFF the FREQ feature.
  |                    This feature creates frequency tables for
  |                    charactre variables in HTML format. These tables
  |                    can be displayed by clicking on character variable
  |                    names in VIMO report. Note that a subfolder caled
  |                    "Freq" must exist under the given &PATH.
  |                    (default value is ON)
  |
  |              EXCLUDEFREQ= List the variables you want to exclude them
  |                           from Frequnecy tables. (separated by blank)
  |                           (default value is pstlcode)
  |
  |              ID= List ID variables here. (Separated by blank)
  |                  (default value is IKN)
  |
  | EXAMPLE:      %VIMO (DS=nrs.epidemo,
  |                      path=~/bkup/DQ/NRS/epidemo,
  |                      FMTLIB=Meta,
  |                      METALIB=Meta,
  |                      ID=IKN epi_id
  |                     )
  |
  |               %VIMO (DS=nrs.epidemo,
  |                      path=~/bkup/DQ/NRS/epidemo,
  |                      postal=pstlcode,
  |                      FMTLIB=Meta,
  |                      METALIB=Meta,
  |                      ID=IKN epi_id
  |                     )
  |
  |               %VIMO (DS=nrs.epidemo,
  |                      invalids=off,
  |                      path=~/bkup/DQ/NRS/epidemo,
  |                      FMTLIB=Meta,
  |                      METALIB=Meta,
  |                      ID=IKN epi_id,
  |                      FREQ=off
  |                     )
  |
  | UPDATE:     May 2013 (Xiaoping Zhao)
  |             - create global macro variable realidvars and add numerical
  |               variables with format checks before stats computation
  |             - incorporate %freqid, %numfreq, %histogram macros into the
  |               main vimo
  |
  |             Mar 28, 2014 (Nicholas Gnidziejko)
  |             - Automatically create /Freq subfolder for output of .png
  |               and .html
  |
  |             April, 2014 (Sean Ji)
  |             - create macro variable datevars and qdatevars which used
  |               in %freq_html
  |             - change datetime15. to datetime20. to solve the problem
  |               when computing the min and max for datetime variables
  |             - slove the issue: median is missing when numeric variables without
  |               user defined formts
  |
  |             17 Oct, 2014 (Gangamma Kalappa)
  |             -  implementation to calculate valid and invalid percentage
  |                of TIME variables and dispaly them in
  |                date/time section in HTML page of VIMO.
  |
  |              March 2015 (Sean Ji)
  |              - add option validvarname=v7;
  |
  |         March 2015 (Gangamma Kalappa)
  |              - added a new parameter to VIMO called log; to suppress the writing 
  |                of log while VIMO is executed. Default value of log is OFF.
  |              - to prevent opening of HTML files while executing VIMO; so that VIMO
  |                can be run through EG.
  |              - fix to prevent the error-xtpush called without xtpushi or xtpushx first
  |         
  |         Nov 5, 2015 (Mahmoud Azimaee)
  |            - Added these four new parameters:  
  |               - offline,
  |               - scriptsLINUXpath,
  |               - scriptsRAEpath,
  |               - scriptsWINpath,
  |            
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

/*
Note:
      IDIN = List of ID variables separated by comma with quotation

      NUMVARFMTLIST  : List of numeric variables with user defined formats
      QNUMVARFMTLIST : List of numeric variables with user defined formats separated by comma with quotation

      DATEVARS : List of variables with standard SAS date or datetime formats
      QDATEVARS : List of variables with standard SAS date or datetime formats separated by comma with quotation

      RealNumVarList:  List of numeric variables which we want to generate descriptive statistics for them.
*/


%MACRO VIMO(DS=,
            INVALIDS= ON,
            PATH=,
            POSTALS=,
            FMTLIB= FORMATS,
            METALIB= META,
            FREQ= ON,
            EXCLUDEFREQ= pstlcode,
            ID=IKN,
            time=fiscal,
		    log=OFF,
		    scriptsRAEpath=U:\1.ices\scripts\,  
		    scriptsWINpath=https://inside.ices.on.ca/dataprog/scripts/
);



   options minoperator;

     /*March 2015 update-Addition of parameter to turn off log by re-directing log to dummy file*/
  %if %upcase(&log)=OFF %then %do;
      filename junk dummy;
      proc printto log=junk;
      run;
  %end;
  /*End of March 2015 update-Addition of parameter to turn off log*/

  /*March 2015 update-to prevent opening of HTML files while executing VIMO*/
  %local odsdes;
  proc sql;
    create table odsdestinations as
      select destination from dictionary.destinations;
  quit; /*Query to create a dataset with all output destinations that 
          have been chosen by user in the current SAS EG session*/

  data odsdestinations;
    set odsdestinations;
    bracket_pos=findc(destination,"(");
    if bracket_pos gt 0 then do;
      odsdes=upcase(substr(destination,1, bracket_pos-1));
    end;
    else do;
      odsdes=upcase(strip(substr(destination,1)));
    end;
    drop bracket_pos;
  run;

  proc sql noprint;
    select odsdes into:odsdes separated " " from odsdestinations;
  quit; /*Creating a local variable with list of ODS destinations user has 
      chosen in current EG session*/

  proc datasets library=work;
    delete odsdestinations;
  quit;

  ods _all_ close;
  /*End of March 2015 update-to prevent opening of HTML files while executing VIMO*/

  /*****************************************************************
  make sure proc tranpose won't cause any problem when the program
  runing in SAS EG
  ******************************************************************/
  %local validvarname;
  %let validvarname=%sysfunc(getoption(validvarname, keyword));
  options validvarname=v7;

   %LET INVALIDS=%UPCASE(&INVALIDS);
   %LET EXCLUDEFREQ=%UPCASE(&EXCLUDEFREQ);

   /* Clean up and add qoutation marks between ID vars to use with IN operator*/
   %LET ID=%UPCASE(&ID);
   %LET ID=%SYSFUNC(COMPRESS(%SYSFUNC(TRANSLATE("&ID",' ',',')),'"'));
   %LET DOI=%EVAL(%SYSFUNC(COUNTC(&ID,' '))+1);
   %LET IDIN=;
   %DO I=1 %TO &DOI;
       %LET IDTEMP=%SCAN(&ID,&I," ");
       %LET IDIN=&IDIN "&IDTEMP";
   %END;

   %GLOBAL IDVARS NVARLIST_OUTLIER;
   %LET IDVARS=&ID. &excludefreq;
   %LET VARN=;
   %LET IDVARS=%SYSFUNC(COMPRESS(%SYSFUNC(TRANSLATE("&IDVARS",' ',',')),'"'));

   ***update: IDVARS includes excludefreq variables, create global macro variable realidvars ***;
   %global REALIDVARS;
   %LET REALIDVARS = &ID;

*******************************************************************;
   PROC FORMAT;
      VALUE $MISSCH " " = "Missing"
                  OTHER = "Nonmissing";
   RUN;
   %GETVARLIST (&DS);
   proc contents data=&LIB..&DSN  out=contents (rename=(name=varname LABEL=VARLABEL)) noprint;
   run;
   DATA CONTENTS;
      SET CONTENTS;
      VARNAME=UPCASE(VARNAME);
   RUN;
*******************************************************************;

  %global numvarfmtlist qnumvarfmtlist datevars qdatevars timevars qtimevars;
  %let numvarfmtlist=;
  %let qnumvarfmtlist=;
  %let datevars=;
  %let qdatevars=;
  %let timevars=;
  %let qtimevars=;

  PROC SQL NOPRINT;
    select strip(NAME),
           quote(strip(NAME))
    into :numvarfmtlist separated " ",
         :qnumvarfmtlist separated ","
    from &METALIB..metadata
    where libname="&LIB" & memname="&DSN" & lowcase(type)='num' &
           format ^in ('','DATE','DATETIME','BEST','Z', 'TIME') &
           upcase(name) not in (&IDIN);
    select strip(name),
           quote(strip(name))
    into   :datevars  separated " ",
           :qdatevars separated ","
    from   &metalib..metadata
    where  libname="&lib" & memname="&dsn" & lowcase(type)='num' &
           format in ('DATE', 'DATETIME') & upcase(name) not in (&idin);
     select strip(name),
               quote(strip(name))
        into   :timevars  separated " ",
               :qtimevars separated ","
        from   &metalib..metadata
        where  libname="&lib" & memname="&dsn" & lowcase(type)='num' &
               format in ('TIME') & upcase(name) not in (&idin);
  QUIT;


  %LET REALNUMVARLIST = ;
    PROC SQL NOPRINT;
     SELECT strip(NAME) INTO :realnumvarlist SEPARATED " "
     from &METALIB..metadata
     where libname="&LIB" & memname="&DSN" & lowcase(type)='num' &
           format in ('', 'BEST','Z') &
           /*format in ('','DATE','DATETIME','BEST','Z') & */
           upcase(name) not in (&IDIN) ;
    QUIT;
********************************************************************;

   * If there are any numeric variables, do the following;

   %IF &NVARLIST NE %THEN %DO;
                 data content_N;
                     set contents (where=(type=1));
                     I + 1;
                     keep VARNAME VARLABEL FORMAT I;
                 run;

                PROC SORT DATA=CONTENT_N;
                     BY VARNAME;
                RUN;

                proc summary data=&LIB..&DSN N NMISS MEAN MIN MAX ;
                        var &NVARLIST;
                        output out=nvout;
                        run;

                * Calculate Medians ;
                %IF &REALNUMVARLIST ^= %THEN %DO;

                   proc means data=&LIB..&DSN (keep= &REALNUMVARLIST /*drop= &numvarfmtlist &datevars &ID*/ ) noprint qmethod=p2;
                       var _NUMERIC_ ;
                       output out=medians (drop= _TYPE_ _FREQ_) Median= ;
                   run;
                   proc transpose data=medians out=medians (drop=_LABEL_ rename=(_NAME_=VARNAME COL1=MEDIAN) );
                   run;
                   data Medians;
                      set medians;
                      VARNAME=UPCASE(VARNAME);
                      LABEL VARNAME='Variable Name';
                   run;

                %END;

                PROC TRANSPOSE data=NVOUT
                               out=NVOUT;
                        run;

                data NVOUT;
                    set NVOUT;
                    Retain N;
                    if _NAME_ = '_FREQ_' then N=COL2;
                    MISSING=N-COL1;
                    PERCENT=100*MISSING/N;
                    if _NAME_ in ('_TYPE_','_FREQ_') then delete;
                    Type='Num ';
                    _NAME_ = UPCASE (_NAME_);
                    Rename _NAME_ = VARNAME _LABEL_ = VARLABEL COL1=NONMISSING COL2=MIN COL3=MAX COL4=MEAN COL5=STD;
                    LABEL _NAME_='Variable Name'
                           _LABEL_='Variable Label'
                            PERCENT='% of Missing Values';
                    drop N;
                 run;

                %if %length(&qnumvarfmtlist) >0 %then %do;
                data NVOUT;
                  set NVOUT;
                  if varname in (&qnumvarfmtlist) then do;
                      min=.;
                      max=.;
                      mean=.;
                      std=.;
                  end;
                run;
                %end;

                proc sort data=NVOUT;
                        by varname;
                run;

               %IF &REALNUMVARLIST ^= %THEN %DO;
                  proc sort data=MEDIANS;
                      by varname;
                   run;
                   Data NVOUT;
                      Merge NVOUT MEDIANS;
                      by VARNAME;
                   run;
                %END;
                data NVOUT DTOUT IDOUT TOUT;
                    length type $ 10;
                    merge content_N(keep=varname format) NVOUT(in=in_NVOUT) ;**update: switch inputdata order;
                        by varname;
                        if in_NVOUT;
                        VARNAME=UPCASE(VARNAME);
                       if format =:'DATETIME' then do;
                          Type='Datetime';
                          output DTOUT;
                          delete;
                       end;
                       else if format in: ('YYMMDDD' , 'DATE' , 'YYMMDD') then do;
                          Type='Date';
                          output DTOUT;
                          delete;
                       end;
                       else if format =:'TIME' then do;
                          Type='Time';
                          output TOUT;
                          delete;
                       end;
                       IF VARNAME IN (&IDIN) THEN DO;
                           Type='ID';
                           output IDOUT;
                           delete;
                       END;
                       output NVOUT;
                       drop format ;
                       run;
        %END;
*******************************************************************;

     * If there are any character variables (inclduing ID vars), do the following;

    %IF &CVARLIST NE %THEN %DO;
         %CHARFREQ(DS=&DS);
         %AUTOLEVEL();

         data content_C;
                 set contents (where=(type=2));
                 I + 1;
                 keep VARNAME VARLABEL FORMAT I ;
                 run;

        PROC SORT DATA=CONTENT_C;
           BY VARNAME;
        RUN;

        %GETNOBS(&DS);

        DATA CVOUT;
          MERGE CHARFREQ (DROP=COUNT  WHERE=(VALUE=''))
                CONTENT_C ;
          BY VARNAME;
          if Missing=. then missing=0;
          NONMISSING=SYMGETN('NO') - Missing;
          PERCENT=100*MISSING/(MISSING+NONMISSING);
          IF UPCASE(VARNAME) IN (&IDIN) THEN Type='ID  ';
             ELSE Type='Char';
         drop I VALUE;
        RUN;
    %END;


*******************************************************************;
        data miss;
                length min          8
                       max          8
                       min_t    $  40
                       max_t    $  40
                       VARNAME  $  32
                       VARLABEL $ 500
                       type     $  10;**update: add varlabel length to avoid truncation;


                %IF (&NVARLIST NE ) AND (&CVARLIST NE ) %THEN set idout nvout cvout dtout tout;;
                %IF (&NVARLIST EQ ) AND (&CVARLIST NE ) %THEN set cvout;;
                %IF (&NVARLIST NE ) AND (&CVARLIST EQ ) %THEN set idout nvout dtout tout;;

                if type='ID' then do;
                       min=.;
                       max=.;
                       mean=.;
                       STD=.;
                       MEDIAN=.;
                end;
                if type='Datetime' then do;
                       min_t=put(min,datetime20.);
                       max_t=put(max,datetime20.);
                       mean=.;
                       STD=.;
                       MEDIAN=.;
                end;

                if type='Date' then do;
                       min_t=put(min,date9.);
                       max_t=put(max,date9.);
                       mean=.;
                       STD=.;
                       MEDIAN=.;
                end;

                if type='Time' then do;
                       min_t=put(min,time5.);
                       max_t=put(max,time5.);
                       mean=.;
                       STD=.;
                       MEDIAN=.;
                end;

                 if type ^in ('Date', 'Datetime', 'Time') then do;
                       min_t=put(min,comma12.1);    
                       max_t=put(max,comma12.1);
                end;

                if type ^in ('Date','Num', 'Datetime', 'Time') then do;
                       min_t=' ';
                       max_t=' ';
                end;

                VARNAME=UPCASE(VARNAME);
                drop min max;
                rename min_t=MIN max_t=MAX;
                run;

        proc sort data=Miss;
                by VARNAME;
                run;
        proc print data=miss;
        run;
      %IF &CVARLIST NE %THEN %DO;
         data Clevel;
                set clevel;
                VAR=UPCASE(VAR);
         run;
        proc sort data=Clevel;
                by VAR;
                run;
       %END;
        data Miss;
            %IF &CVARLIST NE %THEN %DO;
                merge Miss (in=a) Clevel (in=b);
            %END;
            %ELSE %DO;
               set Miss (in=a);
               b=0;
            %END;
                by VARNAME;
                if a;
                if b then Min=Level;
                if TYPE='ID' then order=1;
                if TYPE='Num' then order=2;
                if TYPE='Char' then order=3;
                if TYPE='Date' or TYPE='Datetime' then order=4;
                if TYPE='Time' then order=4;
                drop Level;
                run;

       /*If there is any eligible numeric variable then run %outlier*/
           %LET VARN=;
           %LET NVARLIST_OUTLIER=;

          PROC SQL NOPRINT;
               SELECT VARNAME INTO: NVARLIST_OUTLIER SEPARATED BY " "
               FROM CONTENTS
               WHERE TYPE=1 & format ^in ('YYMMDDD' , 'DATE' , 'DATETIME', 'YYMMDD', 'TIME')
               %if %length(&qnumvarfmtlist) >0 %then %do;
                and upcase(varname) not in (&qnumvarfmtlist); ** update: exclude num vars with format;
                %end;
               ;
          QUIT;


         %IF &NVARLIST_OUTLIER NE %THEN %DO;

                %OUTLIER(&LIB..&DSN);

                data miss;
                        merge miss outlier;
                        by varname;
                        outlier=100*(outlier_n/(MISSING + NONMISSING));
                        * IF data is binary then do not calculate outlier;
                        if TYPE='Num' & min=0 & max=1 & (-0.0001 <= std - sqrt(mean*(1-mean)) <= 0.001) then outlier=0;
                        if TYPE in ('Date','Datetime', 'ID', 'TIME') then do;
                           outlier=.;
                           invalid=.;
                        end;
                        valid=100 - sum(invalid, percent,outlier);
                        run;
        %END;
        %ELSE %DO;
                data miss;
                        set miss;
                        by varname;
                        outlier=.;
                        outlier_n=.;
                        invalid=.;
                        valid=100 - sum(invalid, percent,outlier);
                        run;
        %END;

        %IF &INVALIDS=ON %THEN %DO;
                %INVALID(DS=&DS, FMTLIB=&FMTLIB, METALIB=&METALIB);
                proc sort data=miss;
                        by varname;
                        run;
                %IF &POSTALS^= %THEN %POSTMUN(POSTALS=&POSTALS , MUNCODES=&MUNCODES); ;
                proc sort data=invalids NODUPKEY;
                        by varname;
                        run;
                data miss;
                        %IF &POSTALS^= %THEN merge miss invalids (rename=(invalid=invalid_n)) POSTMUN;
                        %ELSE merge miss invalids (rename=(invalid=invalid_n)); ;
                        by varname;
                        invalid= 100*(invalid_n / (missing+nonmissing));
                        valid=100 - sum(invalid, percent,outlier);
                        run;
                proc sort data=Miss;
                        by order;
                        run;
                proc sql;
                   create table miss_temp as
                        select
                                type
                                ,Varname
                                ,varlabel
                                ,Valid
                                ,Invalid
                                ,percent as Missing
                                ,outlier
                                ,min
                                ,max
                                ,mean
                                ,MEDIAN
                                ,std
                                ,invalid_codes as Comment
                        from miss;
                        quit;
        %END;
        %IF &INVALIDS^=ON & &POSTALS^= %THEN %DO;
                %POSTMUN(POSTALS=&POSTALS , MUNCODES=&MUNCODES);
                data miss;
                        merge miss POSTMUN;
                        by varname;
                        invalid= 100*(invalid_n / (missing+nonmissing));
                        valid=100 - sum(invalid, percent,outlier);
                        run;
                proc sort data=Miss NODUPKEY;
                        by VARNAME;
                        run;
                proc sort data=Miss;
                        by order;
                        run;
                proc sql;
                   create table miss_temp as
                        select
                                type
                                ,Varname
                                ,varlabel
                                ,Valid
                                ,Invalid
                                ,percent as Missing
                                ,outlier
                                ,min
                                ,max
                                ,mean
                                ,MEDIAN
                                ,std
                                ,invalid_codes as Comment
                        from miss;
                        quit;
        %END;
        %IF &INVALIDS^=ON & &POSTALS= %THEN %DO;
                data miss;
                        length INVALID_CODES $ 500 ;
                        set miss;
                        run;
                proc sort data=Miss NODUPKEY;
                        by VARNAME;
                        run;
                proc sort data=Miss;
                        by order;
                        run;
        %END;

        *********************************;
        *** Note: Outlier and Invalid columns are not mutually exclusive and then Valid Percentage might be negative. The
                  Following codes force Valid percentage to zero if it has a negative value;

        data miss;
                set miss;
                if valid < 0 then valid=0 ;
                varname=upcase(varname);
                label valid='% Valid'
                      invalid='% Invalid'
                      outlier='% Outlier'
                      INVALID_CODES='Comments';
                run;

        /*****************************************************************************
           This section re-order variables to take the variable names with a suffix
           for example dx10code2 is always before dx10code10
           Code derived from Kinwah Fong's works
        *****************************************************************************/

        data miss (drop = stop init);
          set miss;
          length namepart2 8;
          if substr(compress(varname),length(compress(varname)),1) in
            ('0' '1' '2' '3' '4' '5' '6' '7' '8' '9') then do;
            stop = 0;
            init = length(compress(varname));
            do while (stop = 0);
               if substr(compress(varname),init,1) not in ('0' '1' '2' '3' '4' '5' '6' '7' '8' '9')
                then stop = init;
                init = init - 1;
            end;
            namepart1 = substr(compress(varname), 1, stop);
            namepart2 = compress(substr(compress(varname), stop+1, length(compress(varname)) - stop));
          end;
          else do;
            namepart1 = compress(varname);
            namepart2 = .;
          end;
        run;


        data _null_;
          nobs=put(&NO,comma32.0);
          call symput('ttn', nobs); *** &ttn to be put vimo beside dataset name;
        run;

        **** Update: add comments and frequency table for ID variables ****;
        %if %length(&REALIDVARS) gt 0 %then %do;
         %freqid;
        %end;

        *** Update: add frequency table for numerical variables with formats ***;
        %NUMFREQ;
        %DATEFREQ;
        %TIMEFREQ;

        proc sql;
          create table vimo (drop = namepart1 namepart2) as
          select *
          from miss
          order by order, namepart1, namepart2;
        quit;

        *** Create Freq subfolder if it does not already exist under the given &PATH. (UNIX OS) ***;
		%IF &sysscp^=WIN %THEN %DO; 
	        %if %sysfunc(fileexist(&PATH./Freq)) = 0 %then %do;
	         x mkdir &PATH./Freq;
	        %end;
		%END;

        *** Update: add histogram for numberical variables without formats ***;
        %global qhistovars;
        %let qhistovars=" ";
        %histogram;


        %VIMO_HTML(PATH=&PATH, FREQ=&FREQ);


        %IF &FREQ=ON %THEN %DO;
              %FREQ_HTML(PATH=&PATH, METALIB=&METALIB);
        %END;

        proc datasets library=work;
                delete Contents clevel content_c CONTENT_N CVOUT UPDATEDVIMO VALID_VALUES VALIDS VALUES
                       DTOUT NVOUT OUTLIER TOUT IDOUT MISS_TEMP MISS VIMO NUMFMT OTHERFMT TIMEFMT TYPES
             CHARFREQ DATEFMT DATEFREQ FORMATS FREQ IDVARS INVALIDS MISS MISS_ MISS_TEMP NESTEDVAR
             VALUESCHAR VARIABLES VIMO_CHARVARS VIMO_DATEVARS VIMO_IDVARS VIMO_NUMVARS; 
        run;
        quit;
        %SYMDEL  CVARLIST DSN LIB NO NVARLIST ;
        %if %symexist(numvarfmtlist) %then %do;
            %SYMDEL numvarfmtlist ;
        %end;

        %if %symexist(timevars) %then %do;
             %SYMDEL timevars;
             %SYMDEL qtimevars;
        %end;

  /****************************************************************
  restore the default validvarname option
  *****************************************************************/
  options &validvarname;

  /*March 2015 update-Addition of parameter to turn off log-reset to default EG session setting
    by re-directing log from dummy to log window*/
  %if %upcase(&log)=OFF %then %do;
    proc printto log=log;
    run;
  %end;
  /*End of March 2015 update-Addition of parameter to turn off log*/

  /*March 2015 update-to prevent opening of HTML files while executing VIMO-open ODS destinations
   based on user preference for the current EG session*/
  %local maxloop startloop odsvar odslst;
  %let maxloop=%eval(%sysfunc(countc(&odsdes,' '))+1);
  %let odslst= HTML PDF RTF;
  %do startloop=1 %to &maxloop;
    %let odsvar=%scan(&odsdes,&startloop," ");
    %if &odsvar=LISTING %then %do;
      ods &odsvar;
    %end;
    %else %if &odsvar=TAGSETS.SASREPORT13 %then %do;
      filename EGSR temp;
      ods &odsvar file=EGSR;
    %end;
    %else %if &odsvar in &odslst %then %do;
      filename EG&odsvar temp;
      ods &odsvar file=EG&odsvar;
    %end;
  %end;
  /*End of March 2015 update-to prevent opening of HTML files while executing VIMO*/
%MEND VIMO;
