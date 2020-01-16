/*========================================================================  
DataFit Toolkit - Link Graph macro
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
  | MACRO:       LINK_GRAPH
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Sean Ji
  |
  | DATE:        March 2014
  |
  | DESCRIPTION: Based on the given SAS dataset (created in
  |              %LINKABILITY), this Macro generates a
  |              dataset __link6 for creating 3D stackbar of
  |              linkability report.
  |              This macro is a sub-macro of %LINKABILITY.
  |              In %LINKABILITY this macro should be used before
  |              %LINK_SUMMARY
  |
  | PARAMETERS:  data= input dataset,this dataset is created in
  |              %LINKABILITY
  |
  |
  | EXAMPLE:     %setstackbards(data=work._link);
  |
  |  UPDATE :   October 2014, Gangamma Kalappa
  |                - implementation to generate monthly, quarterly
  |                   based linkability reports for a specific time period
  |                   using time option.
  | 	        March 2015, Sean Ji
  |                - add options validvarname=v7;
  |
  |             Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |
  |				Feb 2017, Gangamma Kalappa
  |               -  added one more place holder to match values with following pattern 
  |					 linktype_x* or linktype_xx*; where *x-represents one character 
  |					 (eg : linktype_B or linktype_1D)
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
/**********************************************************************
  define the two macros called by %link_summary
**********************************************************************/
%macro getdsn(data=);
   %local dsn;
   %if %sysfunc(find(&data, .)) %then
      %let dsn = %upcase(%scan(&data,2, .));
   %else
      %let dsn = %upcase(&data);
   &dsn
%mend getdsn;

%macro getlibname(data=);
   %local libn;
   %if %sysfunc(find(&data, .)) %then
      %let libn = %upcase(%scan(&data,1, .));
   %else
      %let libn = "WORK";
   &libn
%mend getlibname;

/**********************************************************************
   the main macro
**********************************************************************/
%macro link_graph(data = work._link);

   /*****************************************************************
     make sure proc tranpose won't cause problem when the program
     runing in SAS EG
   ******************************************************************/
   %local validvarname;
   %let validvarname=%sysfunc(getoption(validvarname, keyword));
   options validvarname=v7;

  /**********************************************************************
   make all paramters to be upcase
  **********************************************************************/

   %let libn        = %getlibname(data=&data);
   %let dsn         = %getdsn(data=&data);
   %let linktype    = %upcase(&linktype);
   /* add the dot to &linktypefmt */
   %let linktypefmtname = %upcase(%SYSFUNC(compress(&linktypefmt,.)));
   %let linktypefmt = &linktypefmtname..;
   /* add dot to the bydatefmt */
   %let bydatefmt   = %upcase(%SYSFUNC(compress(&bydatefmt,.)));
   %let bydatefmt   = &bydatefmt..;
   %let time        = %upcase(%sysfunc(strip(&time)));


  /**********************************************************************
   create a new format which can be applied to missing values and other
   values
  **********************************************************************/
   proc format library=&fmtlib cntlout=_cntlout;
      select &linktypefmtname;
   run;

   data _cntlin;
      set _cntlout end=last;
      output;
      if last then do;
         /* add format for missing values */
         start = "_";
         end   = "_";
         label = "(Missing Values)";
         output;
         /* add format for other values */
         start = "Other";
         end   = "Other";
         label = "Other Values ^{super *}";
         HLO   = "O";
         output;
   end;
   run;

   proc format library=work cntlin=_cntlin;
   run;

  /**********************************************************************
   set the data frame
  **********************************************************************/
   proc sort data=&data;
      by &bydate;
   run;

   /* get the the variables whose value is the percentage of a linkability type */
   proc sql noprint;
      select name into :pctvars separated by " "
      from   dictionary.columns
      where  upcase(libname) = "&libn" and
             upcase(memname) = "&dsn" and
             upcase(name) ne upcase("&bydate")   and
             upcase(name) contains "PRCNT"
      ;
   quit;
   run;

   proc transpose data=&data out=work._linkpct(rename=(col1=typepct _name_=linktype));
      by &bydate;
      var &pctVars;
   run;

   data work._linkpct;
      /* set the same length for LINKTYPE in datasets _LINKPCT and _LINKFREQ   */
      /* suppress the warning when merge the two datasets by LINKTYPE          */
      length linktype     $  30
             linktypedesc $ 100;
      set work._linkpct;
      linktype     = tranwrd(upcase(linktype),"&linktype._", "");
      linktype     = strip(tranwrd(linktype,"_PRCNT", ""));
      linktypedesc = put(linktype, &linktypefmt.);
      drop _label_;
   run;

   /***********************************************************************
     create variable PCTORDER, which use to create variable TYPORDER later.
     PCTORDER cannot help re-order the SUBGROUP in PROC GCHART,
     since GCHART ordered SUBGROUP by alphabetic order.
     The purpose of creating PCTORDER is:
         put the overall smallest percentage  at the top of the stackedbar,
         and the overall biggest percentage at the bottom of the stackedbar.
   ***********************************************************************/

   %if &TIME=MONTHLY %then %do;
        proc sql noprint;
            create table work._linkpct2 as
            select   *, sum(typepct) as pctorder
            from     work._linkpct
           /* make the order of PCTORDER is correct for the linkage time range */
           /* otherwise the order may be not what we want if there  a lot of   */
           /* 100% out of the time range. */
           where input(substr(put(&bydate, &bydatefmt),4,7), best12.) between &startyr. and &endyr.
          group by linktypedesc;
       quit;
       run;
   %end;
   %else %do;
       proc sql noprint;
            create table work._linkpct2 as
            select   *, sum(typepct) as pctorder
            from     work._linkpct
           /* make the order of PCTORDER is correct for the linkage time range */
           /* otherwise the order may be not what we want if there  a lot of   */
           /* 100% out of the time range. */
           where input(substr(put(&bydate, &bydatefmt),1,4), best12.) between &startyr. and &endyr.
          group by linktypedesc;
       quit;
       run;
   %end;

   proc sort data=work._linkpct2 out=work._linkpct;
      by &bydate linktypedesc linktype;
   run;


   /* get the variables whose value is the number of records of a linkability type */
   /*Feb 2017 update*/
   /*proc sql noprint;
      select name into :freqvars separated by " "
      from   dictionary.columns
      where  upcase(libname) = "&libn" and
             upcase(memname) = "&dsn"  and
             upcase(name) ne upcase("&bydate") and
             upcase(name) like "&linktype.^__" escape "^" and
             upcase(name) not contains "PRCNT"
      ;
   quit;
   run;*/
   proc sql noprint;
      select name into :freqvars separated by " "
      from   dictionary.columns
      where  upcase(libname) = "&libn" and
             upcase(memname) = "&dsn"  and
             upcase(name) ne upcase("&bydate") and
             ((upcase(name) like "&linktype.^__" escape "^") or (upcase(name) like "&linktype.^___" escape "^")) and
             upcase(name) not contains "PRCNT"
      ;
   quit;
   run;

   proc transpose data=&data out=work._linkfreq(rename=(col1=freq _name_=linktype));
      by &bydate;
      var &freqvars;
   run;

   proc sort data=work._linkfreq;
      by &bydate linktype;
   run;

   data work._linkfreq2;
      /* set the same length for LINKTYPE in datasets _LINKPCT and _LINKFREQ   */
      /* suppress the warning when merge the two datasets by LINKTYPE          */
      length linktype     $  30
             linktypedesc $ 100;
      set work._linkfreq;
      linktype     = tranwrd(upcase(linktype),"&linktype._", "");
      linktype     = strip(linktype);
      linktypedesc = put(linktype, &linktypefmt.);
      drop  _label_;
   run;

   proc sort data=work._linkfreq2 out=work._linkfreq;
     by &bydate linktypedesc linktype;
   run;

   data work.__link;
      merge work._linkfreq work._linkpct;
      by &bydate linktypedesc linktype;
   run;

   /* create variable BARTOTAL used for screen tip */
   proc sql;
      create table work.__link2 as
        select   *,
                 sum(freq) as bartotal
        from     work.__link
        group by &bydate
        ;
   quit;
   run;

   /* create variable LINKAGERATE */
   /* set the string for valid linkage value  */
   %let linkvalue  = %upcase(&linkvalue);
   %let linkvalue  = %sysfunc(compbl(%sysfunc(strip(&linkvalue))));
   %let linkvalues = %sysfunc(tranwrd("&linkvalue", %str( ), %str(", ")));
   proc sql;
     create table work.__link3 as
       select a.* , b.linkagerate
       from work.__link2 as a
       left join
       ( select   &bydate, sum(typepct) as linkagerate
         from     work.__link2
         where    strip(linktype) in (&linkvalues)
         group by &bydate ) as b
       on a.&bydate eq b.&bydate
       order by &bydate, linktypedesc, linktype;
       ;
   quit;
   run;

   /* One LINKTYPEDESC may include several LINKTYPE values, group them together */
   proc sort data=work.__link3;
     by &bydate. linktypedesc;
   run;

   data work.__link4(drop =linktype
                    rename=(freq=freq2 typepct=typepct2
                            sumfreq=freq sumtypepct=typepct));
      length linktypes $ 500;
      retain linktypes;
      set work.__link3;
      by &bydate linktypedesc;
      if first.linktypedesc then do;
         linktypes = "";
         call missing(sumfreq);
         call missing(sumtypepct);
      end;
         linktypes = catx(",", linktypes, linktype);
      sumfreq+freq;
      sumtypepct+typepct;
      if last.linktypedesc;
   run;

   data work.__link4;
      set work.__link4;
      if vvalue(&bydate)="Other Years" then delete;
   run;


   data work.__link5;
      set work.__link4;
      length htmlvar $ 500;

      %if &TIME=MONTHLY %then %do;
          yr = substr(put(&bydate, &bydatefmt),4,7);
      %end;
      %else %do;
          yr = substr(put(&bydate, &bydatefmt),1,4);
      %end;

      typepct = typepct/100;
      linkagerate = linkagerate/100;
      htmlvar = "title="||quote(
                "Category: " ||trim(put(&bydate, &bydatefmt))     ||" "||"0d"x||
                "Type: "     ||strip(tranwrd(linktypedesc, "^{super *}", "")) ||" "||"0d"x||
                "N: "        ||trim(left(freq))                   ||" "||"0d"x||
                "Percent: "  ||trim(left(put(typepct,percent8.2)))||" "||"of "||
                               trim(left(bartotal)));

      drop type;
   run;

   proc sort data=work.__link5;
      by &bydate descending pctorder;
   run;

   /* create TYPEORDER variable, which used in subgroup of proc gchart */
   data work.__link6;
      retain typeorder 0;
      set work.__link5;
      by &bydate;
      if first.&bydate then typeorder=0;
      typeorder=typeorder+1;
      where input(yr, best12.) between &startyr. and &endyr.;
   run;
      
   /****************************************************************
     restore the default validvarname option
   *****************************************************************/
   options &validvarname;
%mend link_graph;
