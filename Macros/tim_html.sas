/*========================================================================  
DataFit Toolkit - Tim HTML macro
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
  | MACRO:       tim_html 
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Sean Ji 
  |
  | DATE:        March 2015
  |
  | DESCRIPTION: For the given SAS datasets, this macro generates a 
  |              html tim report.
  |              This macro is the sub-macro of %tim
  
  | PARAMETERS:      data = &ds._tim,
  |                  title_lib=&library,
  |                  title_ds=&data,
  |                  title_yrtype=&yeartype,
  |                  title_refvar=&refdate,
  |                  htmlpath=&path,
  |                  startyr = &start,
  |                  endyr = &end
  |
  |
  | EXAMPLE:     %missingvalue_html(
  |                     data = CIC_tim1,
  |                     title_lib=cic,
  |                     title_ds=cic,
  |                     title_yrtype=calendar,
  |                     title_refvar=landing_date,
  |                     htmlpath=/users/sji/data/test
  |                 );
  |
  | UPDATES:     2015-03-30 (Sean)
  |              - Fix the bug: when run %tim based on
  |                datasets and not by refdate variable, the header 
  |                have the "Based on CALENDARY Year of" in it. Now
  |                it shows "Based on the Yearly Datasets".
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
%macro tim_html(
    data = &ds._tim,
    title_lib=&library,
    title_ds=&data,
    title_yrtype=&yeartype,
    title_refvar=&refdate,
    htmlpath=&path,
    startyr = &start,
    endyr = &end
);
%local varn i j reportwidth title;
/* generate the macro variable using for title */
%put title_refvar = &title_refvar;
%if %length(&title_refvar) = 0 %then
    %do;
        %let title = Percentage of Missing Values Over Time, Based on the Yearly  Datasets;
    %end;
%else
    %do;
        %let title = Percentage of Missing Values Over Time, Based on %upcase(&title_yrtype) Year of %upcase(&title_refvar);
	%end;
/* define the format using for coloring the cells */
proc format;
    value bgcolor 0        = 'cx99FF99'
                  0<-<20   = 'cxCCFF99'
                  20-<40   = 'cxFFFF99'
                  40-<60   = 'cxFFCC99'
                  60-<80   = 'cxFF9999'
                  80-<100  = 'cxFF7C80'
                  100      = 'cxFF5050'
    ;
    value fgcolor 80-<100  = 'cxFFEEEE'
                  100      = 'white'
                  other    = 'black'
    ;
    value valfmt  0-<100   = [5.2]
                  100      = [3.]
    ;
run;

proc format library = work 
            cntlout = _legend;
    select bgcolor;
run;

/* create the dataset using for display the legned */
data _legend;
    set _legend;
    if sexcl = 'Y' then start = strip(start)||'<';
    else start=strip(start);
    if eexcl = 'Y' then end = '<'||strip(end);
    else end=strip(end);
    keep start end label;
    rename start=FROM end=TO;
run;

proc sql noprint;
    select Label into :label1-:label7
    from   _legend
    ;
quit;

proc transpose data = _legend out = _legend(drop = _label_);
    var from to;
run;

/* recreate the missing values dataset for proc report */
/* moving the column, label, to the end of the dataset (i.e. ) the last column of the dataset */
data &data.;
    set &data(rename = (label=label1)) end = eof;
    length label $ 256;
    if _n_ = 1 then
        do;
            call missing(label);
            varname = 'Number of Observations';
        end;
    else label = label1;
    drop label1;
    if not (eof and varname='filler') then output;
run;

/* get the length of each column in the report */
proc sql noprint;
  select max(length(strip(label))),
         min(max(length(strip(varname))), 32)
    into :label_maxlen,
         :varname_maxlen
  from   &data
  ;
  %put startyr=&startyr;
  %put endyr = &endyr;
  select varname,
         %do i=&startyr. %to &endyr.;
            %if &i ne &endyr. %then 
                %do;
                    max(length(strip(put(count&i., comma32.))), 5),
                %end;
            %else 
                %do;
                    max(length(strip(put(count&i., comma32.))), 5)
                %end;
         %end;
    into :dummy,
         %do i=&startyr. %to &endyr.;
            %if &i ne &endyr. %then 
                %do;
                    :maxlen_count&i.,
                %end;
            %else 
                %do;
                    :maxlen_count&i.
                %end;
         %end;
  from   &data
  where  varname = 'Number of Observations'
  ;
quit;

%let reportwidth = %eval(&label_maxlen + &varname_maxlen);
%do i=&startyr. %to &endyr.;
    %let reportwidth = %eval(&reportwidth + &&maxlen_count&i);
%end;

%put reportwidth = &reportwidth;
%put label_maxlen = &label_maxlen;
%put varname_maxlen = &varname_maxlen;
%do i=&startyr. %to &endyr.;
    %put maxlen_count&i = &&maxlen_count&i;
%end;


/* get all the column names in the missing value dataset */
proc transpose data = &data.(obs = 0) out = _varlist_;
    var _all_;
run;

proc sql noprint;
  select _name_ into :varlist separated by ' '
  from   _varlist_
  ;
quit;

/* generate the html missing values report*/
filename odsout "&htmlpath";
ods listing close;
ods tagsets.htmlpanel options(embedded_titles="no" pagebreak="no" panelrows='2')
                     path=odsout file="&data..html" 
                     (title="&title") 
                      style=sasweb;
ods escapechar="^";

ods tagsets.htmlpanel event=panel(start);
title;
title3    j=center color=black height=14pt "%upcase(&title_lib).%upcase(&title_ds)";
title4    j=center color=black height=12pt "&title";
/* title5    j=center color=black height=10pt "Legend"; */
/* print out the legend*/
proc report data = _legend
    nowd noheader;
    column _name_ col1-col7;
    define _name_ / style = [foreground=white background=cx00669D verticalalign=middle];
    define col1   / style = [background =&label1 foreground=black verticalalign=middle]; 
    define col2   / style = [background =&label2 foreground=black verticalalign=middle]; 
    define col3   / style = [background =&label3 foreground=black verticalalign=middle]; 
    define col4   / style = [background =&label4 foreground=black verticalalign=middle]; 
    define col5   / style = [background =&label5 foreground=black verticalalign=middle]; 
    define col6   / style = [background =&label6 foreground=cxFFEEEE verticalalign=middle]; 
    define col7   / style = [background =&label7 foreground=white verticalalign=middle]; 
run;
title5;
title4;
title3;
ods tagsets.htmlpanel event=panel(finish);


/* print out the missing values report */
ods tagsets.htmlpanel event=panel(start);
footnote;
footnote3 j=right height=8pt color=grey "This report was updated on %sysfunc(left(%qsysfunc(date(),worddate18.)))";
proc report data = &data. 
    nowd 
    style(report)=[outputwidth = %sysevalf(&reportwidth./10)in foreground=white background=cx00669D font_size=10pt cellspacing=0 verticalalign=middle]
    style(header)=[foreground=white background=cx00669D font_size=10pt cellspacing=0 verticalalign=middle]
    style(column)=[foreground=black fontfamily=helvetica font_size=10pt bordercolor=lightgrey borderwidth=1];
    column %sysfunc(strip(&varlist));

    %do i=1 %to %sysfunc(countw(&varlist, %str( )));
        %let varn = %scan(&varlist, &i, %str( ));
        %if &i=1 %then 
            %do;
                define &varn / display width = &varname_maxlen. style = [verticalalign=middle]; 
            %end;
        %else %if &i lt %sysfunc(countw(&varlist, %str( ))) %then
            %do;
                %let j=%eval(&startyr. + &i. - 2);
                define &varn / display width = &&maxlen_count&j format = valfmt.  style = [background=bgcolor. foreground=fgcolor. verticalalign=middle];                
            %end;
        %else %if &i=%sysfunc(countw(&varlist, %str( ))) %then
            %do;
                define &varn / display format = %sysfunc(compress($&label_maxlen..)) style(column) = [verticalalign=middle];
            %end;
    %end;

    %do i=2 %to %eval(%sysfunc(countw(&varlist, %str( )))-1) /*%sysfunc(countw(&varlist, %str( )))*/;
    %let varn = %scan(&varlist, &i, %str( ));
    %put varn = &varn;
    compute &varn;
        if varname="Number of Observations" then do;
            call define(_col_, 'format', 'comma32.');
            call define(_row_, "STYLE", "STYLE=[background=cxC8C8C8 foreground=black font_weight=bold textalign=r]");
        end;
    endcomp;
    %end;
run;


footnote3;

ods tagsets.htmlpanel event=panel(finish);


ods tagsets.htmlpanel close;
ods listing;
filename odsout clear;

/* Delete interim datasets*/

	proc datasets lib=work;
		delete _LEGEND _NOBS _VARLIST_;
	quit;

%mend tim_html;


