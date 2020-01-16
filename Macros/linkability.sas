/*========================================================================  
DataFit Toolkit - Linkability macro
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
 |  MACRO:       LINKABILITY
 |
 |  JOB:         Data Quality
 |
 |  PROGRAMMER:  Mahmoud Azimaee
 |
 |  DATE:        APRIL 2012
 |
 |  DESCRIPTION: This Macro generates a linkability report for a single SAS
 |               dataset or for a series of datasets with the same prefix
 |               name.
 |               There should be a SAS date variable along with a Linkage
 |               Type
 |               variable in the dataset(s) in order to create this table.
 |               Macro stores the final report in an HTML format into the
 |               requested
 |               &PATH. The report can be prepared by Fiscal or Calnedar
 |               year.
 |               The default is fiscal year.
 |
 |  PARAMETERS:  DS= Complete name of a dataset or the first few common
 |                   characters of a  series of datasets as a prefix
 |
 |               DSPREFIX= If DS is a prefix then DSPRIFIX should be ON
 |                         (Default value is OFF)
 |
 |               BYDATE= Desired Date variable (Must be SAS Date variable)
 |
 |               FMTLIB= format library. (Default value is FORMATS)
 |
 |               LINKTYPE= The variable which contains type of linkage
 |                         or primary ID type.
 |
 |               LINKTYPEFMT= The format of LINKTYPE variable, using for
 |                            the reoprt header and the graph legend value
 |                            (if don't know the format, just give a simple
 |                            format like $w. e.g., $50.)
 |
 |               LINKVALUE = The values are valid using for data linkage.
 |                           This parameter is used to calculate linkage
 |                           rate for the report.
 |
 |               STARTYR= Beginning year (1st part for fiscal, 4-digit)
 |
 |               ENDYR= Ending year (1st part for fiscal, 4-digit)
 |
 |               TIME= Must be either FISCAL or CALNEDAR (DEFAULT VALUE
 |                     IS FISCAL)
 |
 |               PATH = Specify a location for storing HTML Linkability
 |                      report
 |
 |  EXAMPLE:     %LINKABILITY (DS=CIHI.CIHI,
 |                             DSPREFIX=ON,
 |                             BYDATE=DDATE,
 |                             LINKTYPE=VALIKN,
 |                             LINKTYPEFMT=$VALIKN.,
 |                             LINKVALUE=D P H V,
 |                             STARTYR=1988,
 |                             ENDYR=2011,
 |                             PATH=~/temp
 |                            );
 |
 |               %LINKABILITY (DS=cic.cic2010,
 |                             BYDATE=landing_date,
 |                             LINKTYPE=link_type,
 |                             LINKTYPEFMT=$LINKTYPE.,
 |                             LINKVALUE=D P H V,
 |                             STARTYR=1980,
 |                             ENDYR=2011,
 |                             TIME=CALENDAR,
 |                             PATH=~/temp
 |                            );
 |  UPDATED:    January 2014, Sean Ji
 |                - add two parameters: linktype and linkvalue
 |                - generate a linkage rate table and a 3D stackedbar chart
 |                  for a specific dataset in a HTML format.
 |                - Three macros added: %link_graph, %link_summary,
 |                  %createlinkhtml
 |
 |              October 2014, Gangamma Kalappa
 |                - implementation to generate monthly, quarterly
 |                   based linkability reports for a specific time period
 |                   using time option.
 |
 |              March 2015, Sean Ji
 |                - add options validvarname=v7;
 |
 |              April 2016, Sean Ji
 |                - fixed the bug: when dsprefix = on, the report cannot
 |                  capture missing values for &linktype variable.
 |
 |              Nov 2016, Mahmoud Azimaee
 |              - Major updates on all macros in order to make them compatible with SAS PC  
 |            
 |              Dec 2016, Sean Ji
 |              - Added the code to let the parameter BYDATE can take DATETIME variable 
 |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%MACRO LINKABILITY (DS=,
                    DSPREFIX= OFF,
                    BYDATE=,
                    FMTLIB= FORMATS,
                    LINKTYPE=,
                    LINKTYPEFMT=,
                    LINKVALUE=D P H V,
                    STARTYR=,
                    ENDYR=,
                    TIME=FISCAL,
                    PATH=
                   );
   /**********************************************************************
      save options
   **********************************************************************/
   proc optsave key='core\options';
   run;

   options validvarname=v7;

   /**********************************************************************
     create a dataset containing one observation for each defined title
   **********************************************************************/
   proc sql noprint;
      create table _title_ as
         select type, number, text
         from   sashelp.vtitle
         where upcase(type)="T"
         ;
   quit;
   run;

   /**********************************************************************
      create a dataset contianing one observation for each defined footnote
   **********************************************************************/
   proc sql noprint;
      create table _footnote_ as
         select type, number, text
         from   sashelp.vtitle
         where  upcase(type)="F"
         ;
   quit;
   run;

   %LOCAL BYDATEFMT bydatefmtindata;
   %LET TIME=%UPCASE(&TIME);

   %IF &TIME=FISCAL %THEN %FISCALYR(%EVAL(&STARTYR-40),%EVAL(&ENDYR+40));
   %ELSE %IF &TIME=CALENDAR %THEN %CALENDARYR(%EVAL(&STARTYR-40),%EVAL(&ENDYR+40));
   %ELSE %IF &TIME=MONTHLY %THEN %MONTHLY(%EVAL(&STARTYR-40),%EVAL(&ENDYR+40));
   %ELSE %IF &TIME=QUARTERLY %THEN %QUARTERLY(%EVAL(&STARTYR-40),%EVAL(&ENDYR+40));

   %IF &TIME = FISCAL %THEN %DO;
      %LET BYDATEFMT =%str(FY.);
   %END;
   %ELSE %IF &TIME=CALENDAR %THEN %DO;
       %LET BYDATEFMT =%str(CY.);
   %END;
   %ELSE %IF &TIME=MONTHLY %THEN %DO;
       %LET BYDATEFMT =%str(monthly.);
   %END;
   %ELSE %IF &TIME=QUARTERLY %THEN %DO;
       %LET BYDATEFMT =%str(quarterly.);
   %END;


  /********************************************
    Find out the &refdate associated format 
  *********************************************/
  %if %upcase(&DSPREFIX) = OFF %then %do;
    %GETVARLIST (&DS);
  %end;
  %else %if %upcase(&DSPREFIX) = ON %then %do;
    %GETVARLIST (&DS.&STARTYR.);
  %end; 
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

   /* For a single dataset */
   %IF %UPCASE(&DSPREFIX)=OFF %THEN %DO; 
      %if %sysfunc(compress(&bydatefmtindata, ., d)) = DATETIME %then %do;
        data _DS;
          set &DS (keep = &linktype &bydate);
          &bydate = datepart(&bydate);
          format &bydate date9.;
        run;
      %end;
	  %else %if %sysfunc(compress(&bydatefmtindata, ., d)) = DATE %then %do;
	    data _DS;
          set &DS (keep = &linktype &bydate);
          format &bydate date9.;
        run;
	  %end;
      PROC FREQ DATA=_DS NOPRINT;
         TABLE  &LINKTYPE * &BYDATE / LIST OUT=_LINK (DROP=PERCENT);
         FORMAT &BYDATE &BYDATEFMT.;
         WHERE  &BYDATE ^=.;
      RUN;

      DATA _LINK;
         SET _LINK;
         IF &LINKTYPE='' THEN &LINKTYPE="_BLANK_";
      RUN;
    %END;


   /* For a series of datasets with a prefix */;
   %IF  %UPCASE(&DSPREFIX)=ON %THEN %DO;
      %DO YEAR=&STARTYR %TO &ENDYR;
        %if %sysfunc(compress(&bydatefmtindata, ., d)) = DATETIME %then %do;
          data _DS&YEAR;
            set &DS.&YEAR (keep = &linktype &bydate);
            &bydate = datepart(&bydate);
            format &bydate date9.;
          run;
        %end;
        %else %if %sysfunc(compress(&bydatefmtindata, ., d)) = DATE %then %do;
          data _DS&YEAR;
            set &DS.&YEAR. (keep = &linktype &bydate);
            format &bydate date9.;
          run;
        %end;
        PROC FREQ DATA=_DS&YEAR NOPRINT;
          TABLE &LINKTYPE * &BYDATE / LIST OUT=_LINK&YEAR (DROP=PERCENT);
          FORMAT &BYDATE &BYDATEFMT.;
          WHERE &BYDATE ^=.;
        RUN;
      %END;

      DATA _LINK;
         SET _LINK&STARTYR - _LINK&ENDYR ;
         /* Delete out of range dates; Added on Nov 11, 2013 */
         IF PUT(&BYDATE, &BYDATEFMT.) = 'Other Years' THEN DELETE;
         IF &LINKTYPE='' THEN &LINKTYPE="_BLANK_";
      RUN;

   %END;

   /* Continue for both cases */
   PROC SORT DATA=_LINK;
      BY &BYDATE &LINKTYPE;
   RUN;

   PROC MEANS DATA=_LINK NOPRINT;
      VAR COUNT;
      BY &BYDATE &LINKTYPE;
      OUTPUT OUT=_LINK2 (DROP=_TYPE_ _FREQ_) SUM=COUNT;
   RUN;

   DATA _LINK2;
      SET _LINK2;
      _YEAR=PUT (&BYDATE,&BYDATEFMT.);
   RUN;

   PROC SORT DATA=_LINK2;
      BY _YEAR &LINKTYPE;
   RUN;

   DATA _LINK3;
      SET _LINK2;
      RETAIN _COUNT;
      BY _YEAR &LINKTYPE;
      IF FIRST.&LINKTYPE THEN _COUNT=0;
      _COUNT = COUNT + _COUNT;
      IF LAST.&LINKTYPE;
   RUN;

   PROC SORT DATA=_LINK3;
      BY &BYDATE;
   RUN;

   PROC TRANSPOSE DATA=_LINK3 OUT=_LINK (DROP= _NAME_ _LABEL_) PREFIX=&LINKTYPE._;
      BY &BYDATE;
      VAR _COUNT;
      ID &LINKTYPE;
      IDLABEL &LINKTYPE;
   RUN;

   PROC SQL NOPRINT;
      SELECT NAME INTO :VARLIST SEPARATED BY " "
      FROM DICTIONARY.COLUMNS
      WHERE LIBNAME = "WORK" AND MEMNAME = "_LINK" AND UPCASE(NAME) ^= UPCASE("&BYDATE");
   QUIT;


   %LET DOI=%EVAL(%SYSFUNC(COUNTC(&VARLIST,' '))+1);
   DATA _LINK;
      SET _LINK;
      %LET TOTAL = %SYSFUNC(TRANSLATE(&VARLIST,","," "));
      %LET TOTAL = %SYSFUNC(COMPRESS("TOTAL=SUM(&TOTAL.)",'"'));
      &TOTAL;
      %DO I=1 %TO &DOI;
         %LET VAR = %SCAN(&VARLIST,&I," ");
         %LET VAR = %SYSFUNC(COMPRESS("&VAR._PRCNT=100*&VAR/TOTAL",'"'));
         &VAR;
      %END;
      %LET TOTAL=%SYSFUNC(COMPRESS("TOTAL=&TOTAL",'"'));
      DROP TOTAL;
   RUN;


  /**********************************************************************
      must call %link_graph before %link_summary
      %link_summary use the dataset,WORK.__LINK6,which created in the macro
      %link_graph
  **********************************************************************/
  /* set the dataset used for creating linkability graph */
  %link_graph( data = work._link );

  /* set the dataset used for linkability report */
  %link_summary( data = work.__link6 );


  /**********************************************************************
      create the linkability html file
  **********************************************************************/
  %link_html( data     = &ds,
              reportDS = work._linkreport,
              graphDS  = work.__link6
            );

   /**********************************************************************
      load options
   **********************************************************************/
   proc optload key='core\options';
   run;

   /**********************************************************************
      clear the titles defined by the macro and
      declare the original titles;
   **********************************************************************/
   title;
   data _null_;
      set _title_;
      if not missing(text) then
         call execute('title'||strip(number)||' '||'"'||strip(text)||'";');
      else
         call execute('title'||strip(number)||';');
   run;

   /**********************************************************************
      clear the footnotes defined by the macro and
      declare the original footnotes;
   **********************************************************************/
   footnote;
   data _null_;
      set _footnote_;
      if not missing(text) then
         call execute('footnote'||strip(number)||' '||'"'||strip(text)||'";');
      else
         call execute('footnote'||strip(number)||';');
   run;
  /**********************************************************************
    delete the temp files in WORK library
  **********************************************************************/
   PROC DATASETS LIB=WORK MEMTYPE=data nolist;
      DELETE
            %IF %UPCASE(&DSPREFIX)=ON %THEN %DO;
                 _LINK&STARTYR - _LINK&ENDYR
                 _DS&STARTYR - _DS&ENDYR
            %END;
            %ELSE %DO;
              _DS
            %END;
                 _title_ _footnote_
                 _link _link2 _link3
                 /* created in %link_graph and %link_summary*/
                 __link __link1-__link6
                 _linkfreq _linkfreq2
                 _linkpct _linkpct2
                 _linkreport
                 _cntlin _cntlout;
   QUIT;
   RUN;

   %EXIT:;
%MEND LINKABILITY;
