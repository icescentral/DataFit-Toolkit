/*========================================================================  
DataFit Toolkit - Link HTML macro
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
  | MACRO:       LINK_HTML
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Sean Ji
  |
  | DATE:        March 2014
  |
  | DESCRIPTION: For the given SAS datasets, this macro generates a
  |              linkability report including a linkability table
  |              and a stackbar chart.
  |              This macro is the sub-macro of %LINKABILITY.

  | PARAMETERS:  data=      input dataset, for which the linkability
  |                         report create. It is the DS parameter
  |                         in %LINKABILITY
  |              reportds = the dataset used for creating linkability
  |                         table. It's created in %SETREPORTDS
  |              graphds  = the dataset used for creating stackbar
  |                         chart. It's created in %SETSTACKBARDS
  |
  |
  | EXAMPLE:     %link_html(data=cihi.cihi);
  |
  | UPDATES:     2014-05-15 (Nicholas Gnidziejko)
  |               - output html and png file names are now
  |                 <datasetname>_linkability to be consistent with
  |                 other DQ macros
  |
  |              October 2014, Gangamma Kalappa
  |                - implementation to generate monthly, quarterly
  |                   based linkability reports for a specific time period
  |                   using time option.
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
%macro link_html( data        = &ds ,
                  reportds    = work._linkreport,
                  graphds     = work._linkgraph
                );


   /**********************************************************************
      initialization
   **********************************************************************/
   /* Get dataset name without libname */
   %local DSN;
   %if %sysfunc(find(&data.,%str(.))) > 0 %then %let DSN = %lowcase(%scan(&data.,2,%str(.)));
   %else %let DSN = %lowcase(&data.);

   %let name=&DSN._linkability;
   filename odsout "&path";

   /**********************************************************************
    get the legend value for the linkability graph
   **********************************************************************/
   proc sql noprint;
      select   distinct linktypedesc, typeorder
               into     :legendvalue separated by "####",
                        :dummy
      from     &graphds
      order by typeorder desc
    ;
   quit;
   run;
   %let legendvalue = %sysfunc(tranwrd(&legendvalue,%str( ^{super *}), %str()));
   %let legendvalue = %sysfunc(tranwrd("&legendvalue", ####, %str(" ")));

   /**********************************************************************
    create footnote for "Other Values", which list all the distinct values
   **********************************************************************/
   %if %sysfunc(find(&legendvalue,Other Values, I )) > 0 %then %do;
     %let hasotherval = 1;
     proc sql noprint;
       select distinct linktypes
              into :othervallist separated by ","
       from   &reportds
       where  linktypedesc eq "Other Values ^{super *}"
       ;
     quit;
     run;
   %end;
   %else %do;
     %let hasotherval = 0;
   %end;


   ods listing close;
   ods tagsets.htmlpanel options(embedded_titles="no" pagebreak="no")
                         path=odsout file="&name..html"
                         (title="Linkability of Records by &bydate. in %upcase(&data.) Data")
                         style=sasweb;
   ods escapechar="^";

   footnote3 j=right height=8pt color=grey "This report was updated on %sysfunc(left(%qsysfunc(date(),worddate18.)))";

   goptions reset=all dev=png gunit=pct noborder  hsize=20cm vsize=15cm;
   title3 j=center color=black height=12pt "Linkability of Records by %upcase(&bydate.) in %upcase(&data.) Data";

  /**********************************************************************
    create the linkability stackedbar chart
  **********************************************************************/
   axis1 label=none offset=(2,2) value=(angle=45);
   axis2 label=(j=c 'Linkability' j=c 'Type(%)')
         minor=(number=1) offset=(0,0);

   legend1 label=none shape=bar(3,2) value=(justify=left &legendvalue.)
           position=(center bottom) across=1 down=3 order=descending;

   pattern1 color=CX4F81BD value=solid; /* blue        */
   pattern2 color=CX8064A2 value=solid; /* purple      */
   pattern3 color=CXC0504D value=solid; /* red         */
   pattern4 color=CX9BBB59 value=solid; /* olive green */
   pattern5 color=CX4BACC6 value=solid; /* aqua        */
   pattern6 color=CXF79646 value=solid; /* orange      */

   proc gchart data=&graphds;
      format typepct percent8.2;
      vbar3d &bydate / discrete
                       type=sum
                       sumvar=typepct
                       subgroup=typeorder
                       autoref
                       clipref
                       cref=graycc
                       maxis=axis1
                       raxis=axis2
                       coutline=black
                       cframe=white
                       legend=legend1
                       width=2
                       space=2
                       html=htmlvar
                       des=''
                       name="&name";
   run;
   quit;

   title3 j=center color=black height=12pt "Linkability of Records by %upcase(&bydate.) in %upcase(&data.) Data";
   footnote3 j=right height=8pt color=grey "This report was updated on %sysfunc(left(%qsysfunc(date(),worddate18.)))";
   /**********************************************************************
    create the linkability report table
   **********************************************************************/
   proc report data=&reportds nowd split="/"
        style(report)=[]
        style(header)=[foreground=black background=cxC0C0C0 font_size=10pt cellspacing=0 verticalalign=middle]
        style(column)=[foreground=black fontfamily=helvetica font_size=10pt];

      column (&bydate) (('Link Type Description' linktypedesc),(freq typepct))
             ('Overall' bartotal linkagerate);

      /* define &bydate   / group center style=[background=cxC0C0C0];*/
         define &bydate      / group order=data center style=[background=cxC0C0C0];

      define linktypedesc / across " ";
      define freq         / analysis sum  "Frequency" format=comma32.
                            style(header)=[background=white];
      define typepct      / analysis sum  "Percent"   format=percent9.2 /*if use percent7.2, in some situation the sum of percent is over 100% */
                            style=[background=cxDCDCDC];
      define bartotal     / analysis mean "Total Number/ of Records" format=comma32.
                            style(header)=[background=white];
      define linkagerate  / analysis mean "Linkage Rate" format=percent9.2
                            style=[background=cxC0C0C0];

      compute &bydate;
         if &bydate="Total" then do;
            call define(_row_, "STYLE", "STYLE=[background=cxC0C0C0 font_weight=bold]");
         end;
      endcomp;
      /* list the other values at the end of the report*/
      %if &hasotherval %then %do;
         compute after _page_ / style=[just=l font_size=9pt foreground=grey fontfamily=helvetica];
            line "* Other Values are: &othervallist";
         endcomp;
      %end;

   run;

   ods tagsets.htmlpanel close;
   ods listing;

   title3;
   footnote3;

%mend link_html;
