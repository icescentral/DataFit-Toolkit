/*========================================================================  
DataFit Toolkit - Link Summary macro
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
  | MACRO:       LINK_SUMMARY
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Sean Ji
  |
  | DATE:        March 2014
  |
  | DESCRIPTION: Based on the given SAS dataset (created in another
  |              macro %LINK_GRAPH), this Macro generates a
  |              dataset __linkreport for creating linkability table
  |              This macro is a sub-macro of %LINKABILITY.
  |              In %LINKABILITY this macro must be used after
  |              %LINK_GRAPH
  |
  | PARAMETERS:  data= input dataset,this dataset is created by
  |              %LINK_GRAPH
  |
  |
  | EXAMPLE:     %setreportds(data=work.__link6);
  |
  | UPDATES:     October 2014, Gangamma Kalappa
  |                - implementation to generate monthly, quarterly
  |                   based linkability reports for a specific time period
  |                   using time option.
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
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
%macro link_summary( data = work.__link);

   /**********************************************************************
      set the dataset _linkreport for linkability report table
   **********************************************************************/
   %let libn=%getlibname(data=&data);
   %let dsn =%getdsn(data=&data);
   /* add dot to the bydatefmt */
   %let bydatefmt   = %upcase(%SYSFUNC(compress(&bydatefmt,.)));
   %let bydatefmt   = &bydatefmt..;

   /* get the label of &BYDATE */
   proc sql noprint;
      select label
      into   :bydatelabel
      from   dictionary.columns
      where  upcase(libname)="&libn" and
             upcase(memname)="&dsn" and
             upcase(name)=upcase("&bydate")
      ;
   quit;
   run;

   data __link1;
      set &data ( where=(input(yr, best12.) between &startyr. and &endyr.)
                  rename=(&bydate=bydate));
      &bydate = put(bydate, &bydatefmt);
      label &bydate="&bydatelabel";
   run;

   /* set the last row of the report */
   proc sql noprint;
      create table __link2 as
      select   distinct
               "Total" as &bydate label="&bydatelabel",
               linktypes,
               linktypedesc,
               sum(freq) as freq,
               sum(freq)/sum(bartotal) as typepct,
               sum(bartotal) as bartotal
      from     &data
      group by linktypedesc
      ;
   quit;
   run;

   /* set the string for valid linkage value  */
   %let linkvalue  = %upcase(&linkvalue);
   %let linkvalue  = %sysfunc(compbl(%sysfunc(strip(&linkvalue))));
   %let linkvalues = %sysfunc(tranwrd("&linkvalue", %str( ), %str(", ")));

   proc sql noprint;
     create table __link3 as
       select a.*, b.linkagerate
       from   __link2 as a
       left join
       (select   *,
                sum(typepct) as linkagerate
        from     __link2
        where    linktypes in (&linkvalues)
        ) as b
        on a.&bydate eq b.&bydate and a.linktypes = b.linktypes
      ;
   quit;
   run;

   proc sort data=__link1;
         by &bydate;
   run;

   %if &TIME=MONTHLY %then %do;
       data _linkreport;
             set __link1(keep=bydate &bydate linktypes linktypedesc freq typepct bartotal linkagerate);
             by &bydate;
       run;
       proc sort data=_linkreport;
            by bydate;
       run;
       proc append base= _linkreport data=__link3(keep=bydate &bydate linktypes linktypedesc freq typepct bartotal linkagerate);
       run;

   %end;
   %else %do;
       data _linkreport;
             set __link1(keep=bydate &bydate linktypes linktypedesc freq typepct bartotal linkagerate)
                __link3(keep=/*bydate*/ &bydate linktypes linktypedesc freq typepct bartotal linkagerate);
             by &bydate;
       run;
   %end;
%mend link_summary ;
