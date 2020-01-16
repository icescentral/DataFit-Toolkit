/*========================================================================  
DataFit Toolkit - VIMO HTML macro
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


/*_____________________________________________________________________________
  | MACRO:       VIMO_HTML
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        October 2012
  |
  | DESCRIPTION: This macro is an intermediate macro which will be called
  |              by %VIMO to produce a complete VIMO report in HTML format.
  |
  | PARAMETERS: SUBFOLDER= Name of the subfolder that HTML frequnecy tables will be
  |                        saved in. (Default value is "Freq")
  |
  |             PATH= Location to save the HTML VIMo report,
  |
  |             FREQ= An option for turning ON/OFF the FREQ feature.
  |
  | EXAMPLE:    %VIMO_HTML(PATH=&PATH, FREQ=&FREQ);
  |
  | UPDATE:     May 2013 Xiaoping Zhao
  |             - add dataset label to vimo main html page
  |             - add html links for ID and numerical variables with formats in
  |               vimo main html page
  |             - add html td.tdimo definition and central columns in main vimo page
  |
  |             Mar 28, 2014 (Nicholas Gnidziejko)
  |             - Remove step to create /Freq sub-directory, as this is now
  |               handled in %vimo
  |
  |             April, 2014 (Sean Ji)
  |             - add code to deal with datetime variable
  |
  |             May 15, 2014 (Nicholas Gnidziejko)
  |             - Output file names are now <datasetname>_vimo.html (lowercase
  |               dataset name to be consistent with other DQ macros)
  |
  |             Aug 07, 2014 (Sean Ji)
  |             - separate id varialbes, numeric variables, character variables
  |               and date (time) variables into different talbes. Supress the
  |               unnecessary columns for each type of variables.
  |
  |             Oct 17, 2014 (Gangamma Kalappa)
  |             -Fixing bug to display Time variables in date table in VIMO and
  |               suppress the unnecessary columns for time variables.
  |             
  |             March 09,2015 (Gangamma Kalappa)
  |				- fix in the bug in the label column for numerical variables in 
  |               vimo_html; example- when length of label was greater than 198 
  |               then %Valid column was not populated and the %Valid value appeared
  |               else where in the html file.
  |            
  |            Nov 5, 2015 Major update (Mahmoud Azimaee)
  |            - Add VIMO Graph
  |            - Add JQuery features for popup overlay and hide/show check boxes
  |            
  |            July 18, 2016 Mahmoud Azimaee)
  |            - Fixed some URLs
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%macro vimo_html (subfolder=Freq, path=, FREQ=);

%let ID=;
%let Char=;
%let Num=;
%let Date=;
/* Set VIMO Graph color codes */
%let Vcolor=#9FCC84;
%let Icolor=#FF3737;
%let Mcolor=#FABF8F;
%let Ocolor=#4F81BD;

proc sql;
     select memlabel into: label
     from DICTIONARY.tables as A
     where A.memname="&DSN" & A.libname = "&LIB";
quit;

/* Create VIMO Graph */
data vimo;
	set vimo;
	length gv gi gm go $ 1000;
	gv='';
	gi='';
	gm='';
	go='';

	if round(valid)>0 then do;
		do c=1 to round(valid);
			Gv=compress(Gv||"&#9612;");
		end;
	end;
	if round(invalid)>0 then do;
		do c=1 to round(invalid);
			Gi=compress(Gi||"&#9612;");
		end;
	end;
	if round(percent)>0 then do;
		do c=1 to round(percent);
			Gm=compress(Gm||"&#9612;");
		end;
	end;
	if round(outlier)>0 then do;
		do c=1 to round(outlier);
			Go=compress(Go||"&#9612;");
		end;
	end;
	drop c;
run;
/* End VIMO Graph */

data vimo_idvars   vimo_numvars
     vimo_charvars vimo_datevars;
        set vimo;
		if length (trim(varlabel))> 50 then varlabel=trim(substr(trim(varlabel),1,47) || "...");
        if type='Datetime' then type='Date';
        if type='ID' then output vimo_idvars;
        if type='Num' then output vimo_numvars;
        if type='Char' then output vimo_charvars;
        if type='Time' then type='Date';
        if type='Date' or type='Datetime' or type='Time' then output vimo_datevars;

        array vars{4} varlabel min max INVALID_CODES;
        do I=1 to 4;
                if vars[i]='' then vars[i]='&nbsp;';
        end;
run;

data updatedvimo;
  set vimo;
  if type='Time' then type='Date';
run;
proc means data=updatedvimo noprint;
        var order;
        class type;
        output out=types n=n;
run;

data types;
        set types;
        if type='ID'   then call symput('ID',n);
        if type='Num'  then call symput('Num',n);
        if type='Char' then call symput('Char',n);
        if type='Date' then call symput('Date',n);
run;

filename vimo "&PATH./%lowcase(&DSN.)_VIMO.html";

data _null_ ;
    file vimo encoding='asciiany';
	length href $ 1000;
put '<!doctype html>';
put '<html lang="en">';
put '<head>';


put '<meta charset="utf-8">';

put '<!-- Force latest IE, Google Chrome Frame for IE -->';
put '<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">';

put '<meta name="description" content="jQuery plugin for responsive and accessible modal windows and tooltips." />';
put '<meta name="viewport" content="width=device-width, initial-scale=1.0" />';

put '<!-- Bootstrap styles -->';
href= "<link rel='stylesheet' href='scripts/bootstrap.min.css'><!-- To work offline -->";
put href;
href= "<link rel='stylesheet' href='"||symget('scriptsRAEpath')|| "bootstrap.min.css'><!-- To work in ICES RAE -->";
put href;
href= "<link rel='stylesheet' href='"||symget('scriptsWINpath')||"bootstrap.min.css'><!-- To work in ICES Intranet -->";
put href;
/*put '<link rel="stylesheet" href="https://getbootstrap.com/dist/css/bootstrap.min.css"><!-- To work when Internet is available -->';*//*Old path commented*/
put '<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css"><!-- To work when Internet is available -->';

put '<!-- jQuery -->';
href= '<script src="scripts/jquery-1.8.2.min.js"></script><!-- To work offline -->';
put href;
href= '<script src="'||symget('scriptsRAEpath')||'jquery-1.8.2.min.js"></script><!-- To work in ICES RAE -->';
put href;
href= '<script src="'||symget('scriptsWINpath')||'jquery-1.8.2.min.js"></script><!-- To work in ICES Intranet -->';
put href;
put '<script src="https://code.jquery.com/jquery-1.8.2.min.js"></script><!-- To work when Internet is available -->';

put '<!-- jQuery Popup Overlay -->';
href= '<script src="scripts/jquery.popupoverlay.js"></script><!-- To work offline -->';
put href;
href= '<script src="'||symget('scriptsRAEpath')||'jquery.popupoverlay.js"></script><!-- To work in ICES RAE -->';
put href;
href= '<script src="'||symget('scriptsWINpath')||'jquery.popupoverlay.js"></script><!-- To work in ICES Intranet -->';
put href;
put '<script src="https://cdn.rawgit.com/vast-engineering/jquery-popup-overlay/1.7.13/jquery.popupoverlay.js"></script><!-- To work when Internet is available -->';


put '<!-- jQuery Show/Hide -->';
put '<script>$(window).load(function(){$("input:checkbox").change(function(){var ColToHide = $(this).attr("name");';
put 'if(this.checked){$("td[class=''" + ColToHide + "'']").show();}else{$("td[class=''" + ColToHide + "'']").hide();}';
put '$("div#Debug").text("hiding " + ColToHide);});$("input:checkbox").change(function(){var ColToHide = $(this).attr("name");';
put 'if(this.checked){$("th[class=''" + ColToHide + "'']").show();}else{$("th[class=''" + ColToHide + "'']").hide();}$("div#Debug").text("hiding " + ColToHide);});});</script>';


put '<!-- Custom styles for Popoup page -->';
put '<style>';
put 'img {max-width: 100%;}';
put '.well {box-shadow: 0 0 10px rgba(0,0,0,0.3); background: white; display:none;margin:1em;}';
put 'pre.prettyprint {padding: 9px 14px;}';
put '.fulltable {max-width: 100%;overflow: auto;}';
put '.container {padding-left: 0;padding-right: 0;}';
put '.lineheight {line-height: 3em;}';
put '.pagetop {background: url(http://subtlepatterns.com/patterns/congruent_outline.png) #333;background-attachment: fixed;color: #fff;}';
put '.page-header {border-bottom: none;}';
put '.initialism {font-weight: bold;letter-spacing: 1px;font-size: 12px;}';
put '</style>';


put "<style type='text/css'>";
        put 'p.date { font-family:Arial, sans-serif;';
                        put 'font-size:10.0pt; ';
                        put 'color: gray;';
                        put 'text-align:right;';
                        put '}';

        put 'p.tlabel{ font-family:Arial, sans-serif;';
                        put 'font-size:11.0pt; ';
                        put 'font-weight: 700;';
                        put 'color: black;';
                        put 'text-align:left;';
                        put '}';

        put 'p.foo  { font-family:Arial, sans-serif;';
                        put 'font-size:9.0pt; ';
                        put 'font-weight: 700;';
                        put 'color: gray;';
                        put 'text-align:left;';
                        put '}';

        put 'a.ft   { color: gray;}';

        put 'table {';
                   put 'border: 2px solid black;';
                   put 'border-collapse: collapse;';
                   put 'color:black;';
                   put 'font-family:Arial, sans-serif;';
                   put 'text-decoration: none;';
                   put 'font-size:10.0pt; ';
                   put ' table-layout:auto;';
                   put '}';

        put 'thead {background: lightgray;';
               put 'font-weight: 700;';
               put 'border: 2px solid lightgray;';
               put 'height: 36;';
               put '}';

        put 'tr {height: 25;';
               put ' }';

        put 'td {background: white;';
               put 'text-align:left;';
               put 'border: 2px solid lightgray;';
               put '}';

        put 'td.tdred {color:red;';
               put 'font-weight:700;';
               put ' background:#F2DCDB;';
               put 'text-align:center;';
               put ' }';

        put 'td.tdorange {color:#E26B0A;';
                put 'font-weight:700;';
                put ' background:#FDE9D9;';
                put 'text-align:center;';
                put ' }    ';

        put 'td.tdgreen {color:green;';
                put ' font-weight:700;';
                put 'background:#EBF1DE;';
                put 'text-align:center;';
                put '}';

        put 'td.tdimo {';
                put 'background:white;';
                put 'text-align:center;';
                put '}';

        put 'td.dtrng {';
                put 'background:white;';
                put 'text-align:left;';
                put '}';

put '</style>';

put '<title>VIMO Table</title>';
put '</head>';


put "<h3 align='center'> <font color='#00669D' face='Arial'>VIMO report for dataset &LIB..&DSN </font> </h3>";

%if %length(&label) >0 %then %do;
 put "<h4 align='center'> <font color='#00669D' face='Arial'>&label </font> </h4>";
 put "<h4 align='center'> <font color='#00669D' face='Arial'>N=&ttn </font> </h4>";
%end;
%else %do;
 put "<h2 align='center' <font color='#00669D' face='Arial'>N=&ttn </font> </h2>";
%end;

put '<b>Show:'; 
put '<input name="varlabel" type="checkbox" checked="checked" />Label&nbsp;&nbsp;&nbsp;&nbsp;';
put '<input name="vimograph" type="checkbox" checked="checked" />VIMO Graph </b>';
put '<br><br>';
put "<a name='Top'></a><br/>";
run;

****************************;
** Create HTML file: ID Vars;
****************************;

filename vimo "&PATH./%lowcase(&DSN.)_VIMO.html" MOD;

data _null_;
  length col2-col7  $200 col1 col8 col19 - col21 $1000;
  file vimo ;
  set vimo_idvars end=last;
  if _n_=1 then do;
    put "<p class='tlabel'>ID Variables (&ID)<a name='IDVars'></a></p>";
    put '<table columns="7" cellpadding="4" cellspacing="0" >';
    put '<thead >';
    put '<tr>';
    put '<th >&nbsp; Variable Name &nbsp;</th>';
    put '<th class="varlabel">&nbsp; Variable Label &nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">V</font></u>alid<sup>*</sup>&nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">M</font></u>issing &nbsp;</th>';
    put '<th >&nbsp; Uniqueness &nbsp;</th>';
	col8= '<th class="vimograph">&nbsp; VIMO Graph: &nbsp;&nbsp;'||
	       '<font color="'||symget('Vcolor')||'">&#9612;</font>%Valid &nbsp;&nbsp;'||
		   '<font color="'||symget('Icolor')||'">&#9612;</font>%Invalid &nbsp;&nbsp;'||
		   '<font color="'||symget('Mcolor')||'">&#9612;</font>%Missing &nbsp;&nbsp;'||
		   '<font color="'||symget('Ocolor')||'">&#9612;</font>%Outlier '||'</th>'; 
	put col8;
    put '</tr>';
    put '</thead>';
    put '<tbody>';
  end;

  %if &FREQ = ON %then %do;  
    if  TYPE in ('Char','ID','Date')
    %if %length(&qnumvarfmtlist) >0  %then %do; or upcase(VARNAME) in (&qnumvarfmtlist) %end;  
    %if %length(&qhistovars) >0 %then %do; or lowcase(varname) in (&qhistovars) %end;
	THEN do;
			col1="<td ><a id='"||trim(lowcase(VARNAME))||"_link' class='"||trim(VARNAME)||"_popup_open' href='#"||trim(lowcase(VARNAME))||"'>"||trim(VARNAME)||"</a></td>";
		    col19="<div id='"||trim(VARNAME)||"_popup' class='well'>"||"<iframe id='"||trim(lowcase(VARNAME))||"_iframe' src='about:blank' width='500' height='500' ></iframe></div>";
			col20="<script> $('#"||trim(lowcase(VARNAME))||"_link').click(function () {$('#"||trim(lowcase(VARNAME))||"_iframe').attr('src','Freq/"||trim(lowcase(VARNAME))||".html');";
			col21=" $('#"||trim(VARNAME)|| "_popup').popup({pagecontainer: '.container',transition: 'all 0.3s'});}); </script>" ;
		end;
  %end;
  %else %do;
    col1 = '<td>'||trim(varname)||'</td>';
  %end;

  col2='<td class="varlabel">'||trim(VARLABEL)||'</td>';

  if 98 <= VALID <= 100 then col3='<td class="tdgreen" >'||trim(put(VALID,10.2))||'</td>';
  if 95 <= VALID <   98 then col3='<td class="tdorange" >'||trim(put(VALID,10.2))||'</td>';
  if 0  <= VALID <   95 then col3='<td class="tdred" >'||trim(put(VALID,10.2))||'</td>';

  if PERCENT=. then do;
    col5='<td class="tdimo">'||" "||'</td>';
  end;
  else do;
    col5='<td class="tdimo">'||trim(put(PERCENT,10.2))||'</td>';
  end;

  col7= '<td >'||trim(INVALID_CODES)||'</td>';
  col8=  '<font color = " '||symget('Vcolor')||'">'||trim(GV)||' </font>';
  col16= '<font color = " '||symget('Icolor')||'">'||trim(GI)||' </font>';
  col17= '<font color = " '||symget('Mcolor')||'">'||trim(GM)||' </font>';
  col18= '<font color = " '||symget('Ocolor')||'">'||trim(GO)||' </font>'; 

  put '<tr>';
  put col1;
  put col19;
  put col20;
  put col21;
  put col2;
  put col3;
  put col5;
  put col7;
  put'  <td class="vimograph">';
  put'	<span style="letter-spacing:-4px">';
  put col8;
  put col16;
  put col17;
  put col18;
  put'	</span>';
  put'</td>';
  put'</tr>';

  if last then do;
    put '</table>';
    put "<p class='foo'>Jump to:  <a href='#IDVars' class='ft'>ID</a>&nbsp;&nbsp;<a href='#NumVars' class='ft'>Numeric</a>&nbsp;&nbsp;<a href='#CharVars'
         class='ft'>Character</a>&nbsp;&nbsp;<a href='#DateVars' class='ft'>Date(Time)</a></p></br>";
  end;

run;

*********************************;
** Create HTML file: Numeric Vars;
*********************************;

filename vimo "&PATH./%lowcase(&DSN.)_VIMO.html" MOD;

%local length_varlabel;
proc sql noprint;
	select max(length(varlabel)) into:length_varlabel from vimo_numvars;
quit;
%if &length_varlabel=. %then %let length_varlabel=200;
%else %do;
   %let length_varlabel=%eval(&length_varlabel+20);
%end;
data _null_;
  length col1 $1000 col3-col11 $200 col12 $1000 ;
  file vimo;
  set vimo_numvars end=last;
  if _n_=1 then do;
    put "<p class='tlabel'>Numeric Variables (&num)<a name='NumVars'></a></p>";
    put '<table columns="12" cellpadding="4" cellspacing="0"  >';
    put '<thead >';
    put '<tr>';
    put '<th >&nbsp; Variable Name &nbsp;</th>';
    put '<th class="varlabel">&nbsp; Variable Label &nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">V</font></u>alid<sup>*</sup> </th>';
    put '<th >&nbsp; % <u><font color="#800000">I</font></u>nvalid </th>';
    put '<th >&nbsp; % <u><font color="#800000">M</font></u>issing </th>';
    put '<th >&nbsp; % <u><font color="#800000">O</font></u>utlier </th>';
    put '<th >&nbsp; MIN &nbsp;</th>';
    put '<th >&nbsp; MAX &nbsp;</th>';
	put '<th >&nbsp; MEAN &nbsp;</th>';
    put '<th >&nbsp; MEDIAN &nbsp;</th>';
    put '<th >&nbsp; STD &nbsp;</th>';
	graph= '<th class="vimograph">&nbsp; VIMO Graph: &nbsp;'||
	       '<font color="'||symget('Vcolor')||'">&#9612;</font>%Valid &nbsp;&nbsp;'||
		   '<font color="'||symget('Icolor')||'">&#9612;</font>%Invalid &nbsp;&nbsp;'||
		   '<font color="'||symget('Mcolor')||'">&#9612;</font>%Missing &nbsp;&nbsp;'||
		   '<font color="'||symget('Ocolor')||'">&#9612;</font>%Outlier '||'</th>'; 
	put graph;
    put '</tr>';
    put '</thead>';
    put '<tbody>'; 
  end;

  %if &FREQ = ON %then %do; 
    if  TYPE in ('Char','ID','Date')
    %if %length(&qnumvarfmtlist) >0  %then %do;
		or upcase(VARNAME) in (&qnumvarfmtlist) 
	%end;   
    %if %length(&qhistovars) >0 %then %do;
		or lowcase(varname) in (&qhistovars)
	%end;
	THEN do;
			col1="<td ><a id='"||trim(lowcase(VARNAME))||"_link' class='"||trim(VARNAME)||"_popup_open' href='#"||trim(lowcase(VARNAME))||"'>"||trim(VARNAME)||"</a></td>";
		    col19="<div id='"||trim(VARNAME)||"_popup' class='well'>"||"<iframe id='"||trim(lowcase(VARNAME))||"_iframe' src='about:blank' width='1400' height='630' ></iframe></div>";
			col20="<script> $('#"||trim(lowcase(VARNAME))||"_link').click(function () {$('#"||trim(lowcase(VARNAME))||"_iframe').attr('src','Freq/"||trim(lowcase(VARNAME))||".html');";
			col21=" $('#"||trim(VARNAME)|| "_popup').popup({pagecontainer: '.container',transition: 'all 0.3s'});}); </script>" ;
		end;
    else if TYPE EQ 'Num' then col1 = '<td>'||trim(varname)||'</td>';
  %end;
  %else %do;
    col1 = '<td>'||trim(varname)||'</td>';
  %end;

  col2='<td class="varlabel" >'||trim(VARLABEL)||'</td>';

  if 98 <= VALID <= 100 then col3='<td class="tdgreen" >'||trim(put(VALID,10.2))||'</td>';
  if 95 <= VALID <   98 then col3='<td class="tdorange" >'||trim(put(VALID,10.2))||'</td>';
  if 0  <= VALID <   95 then col3='<td class="tdred" >'||trim(put(VALID,10.2))||'</td>';

  if INVALID=. then do;
    col4='<td class="tdimo">'||" "||'</td>';
  end;
  else do;
    col4='<td class="tdimo">'||trim(put(INVALID,10.2))||'</td>';
  end;

  if PERCENT=. then do;
    col5='<td class="tdimo">'||" "||'</td>';
  end;
  else do;
    col5='<td class="tdimo">'||trim(put(PERCENT,10.2))||'</td>';
  end;

  if OUTLIER=. then do;
    col6='<td class="tdimo">'||" "||'</td>';
  end;
  else do;
    col6='<td class="tdimo">'||trim(put(OUTLIER,10.2))||'</td>';
  end;
  %if %length(&qnumvarfmtlist)>0 %then %do;
    if upcase(VARNAME) in (&qnumvarfmtlist) then col7="<td colspan='5'>"||trim(MIN)||'</td>';
    else  do;
      col7 = '<td>'||trim(MIN)||'</td>';
      col8  = '<td >'||trim(MAX)||'</td>';
      col9  = '<td >'||trim(put(MEAN,comma32.1))||'</td>';
      col10 = '<td >'||trim(put(MEDIAN,comma32.1))||'</td>';
      col11 = '<td >'||trim(put(STD,comma32.1))||'</td>';
    end;
  %end;
  %else %do;
    col7 = '<td>'||trim(MIN)||'</td>';
    col8  = '<td >'||trim(MAX)||'</td>';
    col9  = '<td >'||trim(put(MEAN,comma32.1))||'</td>';
    col10 = '<td >'||trim(put(MEDIAN,comma32.1))||'</td>';
    col11 = '<td >'||trim(put(STD,comma32.1))||'</td>';
  %end;
  col12=  '<font color = " '||symget('Vcolor')||'">'||trim(GV)||' </font>';
  col16=  '<font color = " '||symget('Icolor')||'">'||trim(GI)||' </font>';
  col17=  '<font color = " '||symget('Mcolor')||'">'||trim(GM)||' </font>';
  col18=  '<font color = " '||symget('Ocolor')||'">'||trim(GO)||' </font>'; 

  put '<tr>';
  put col1;
  put col19;
  put col20;
  put col21;
  put col2;
  put col3;
  put col4;
  put col5;
  put col6;
  put col7;
  put col8;
  put col9;
  put col10;
  put col11;
  put'<td class="vimograph">';
  put'	<span style="letter-spacing:-4px">';
  put col12;
  put col16;
  put col17;
  put col18;
  put'	</span>';
  put'</td>';
  put'</tr>';

  if last then do;
    put '</table>';
    put "<p class='foo'>Jump to:  <a href='#IDVars' class='ft'>ID</a>&nbsp;&nbsp;<a href='#NumVars' class='ft'>Numeric</a>&nbsp;&nbsp;<a href='#CharVars'
         class='ft'>Character</a>&nbsp;&nbsp;<a href='#DateVars' class='ft'>Date(Time)</a></p></br>";
  end;

run;

******************************;
** Create HTML file: CHAR Vars;
******************************;

filename vimo "&PATH./%lowcase(&DSN.)_VIMO.html" MOD;
data _null_;
  length  col1-col9 $1000;
  file vimo;
  set vimo_charvars end=last;
  if _n_=1 then do;
    put "<p class='tlabel'>Character Variables (&char)<a name='CharVars'></a></p>";
    put '<table columns="7" cellpadding="4" cellspacing="0" >';
    put '<thead >';
    put '<tr>';
    put '<th >&nbsp; Variable Name &nbsp;</th>';
    put '<th class="varlabel">&nbsp; Variable Label &nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">V</font></u>alid<sup>*</sup>&nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">I</font></u>nvalid &nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">M</font></u>issing &nbsp;</th>';
    put '<th >&nbsp; Values &nbsp;</th>';
	col12= '<th class="vimograph">&nbsp; VIMO Graph: &nbsp;&nbsp;'||
	       '<font color="'||symget('Vcolor')||'">&#9612;</font>%Valid &nbsp;&nbsp;'||
		   '<font color="'||symget('Icolor')||'">&#9612;</font>%Invalid &nbsp;&nbsp;'||
		   '<font color="'||symget('Mcolor')||'">&#9612;</font>%Missing &nbsp;&nbsp;'||
		   '<font color="'||symget('Ocolor')||'">&#9612;</font>%Outlier &nbsp;&nbsp;'||'</th>'; 
	put col12;
    put '</tr>';
    put '</thead>';
    put '<tbody>';
  end;

  %if &FREQ = ON %then %do;  

    if  TYPE in ('Char','ID','Date')
    %if %length(&qnumvarfmtlist) >0  %then %do; or upcase(VARNAME) in (&qnumvarfmtlist) %end;   
    %if %length(&qhistovars) >0 %then %do; or lowcase(varname) in (&qhistovars) %end;
	THEN do;
			col1="<td ><a id='"||trim(lowcase(VARNAME))||"_link' class='"||trim(VARNAME)||"_popup_open' href='#"||trim(lowcase(VARNAME))||"'>"||trim(VARNAME)||"</a></td>";
		    col19="<div id='"||trim(VARNAME)||"_popup' class='well'>"||"<iframe id='"||trim(lowcase(VARNAME))||"_iframe' src='about:blank' width='500' height='500' ></iframe></div>";
			col20="<script> $('#"||trim(lowcase(VARNAME))||"_link').click(function () {$('#"||trim(lowcase(VARNAME))||"_iframe').attr('src','Freq/"||trim(lowcase(VARNAME))||".html');";
			col21=" $('#"||trim(VARNAME)|| "_popup').popup({pagecontainer: '.container',transition: 'all 0.3s'});}); </script>" ;
	end;
	else  col1="<td ><a href='Freq/"||trim(lowcase(VARNAME))||".html'>"||trim(VARNAME)||"</a></td>";
  %end;
  %else %do;
    col1 = '<td>'||trim(varname)||'</td>';
  %end;

  col2='<td class="varlabel">'||trim(VARLABEL)||'</td>';

  if 98 <= VALID <= 100 then col3='<td class="tdgreen" >'||trim(put(VALID,10.2))||'</td>';
  if 95 <= VALID <   98 then col3='<td class="tdorange" >'||trim(put(VALID,10.2))||'</td>';
  if 0  <= VALID <   95 then col3='<td class="tdred" >'||trim(put(VALID,10.2))||'</td>';

  if INVALID=. then do;
    col4='<td class="tdimo">'||" "||'</td>';
  end;
  else do;
    col4='<td class="tdimo"><a class="'||trim(VARNAME)||'_Invalid_open" href="#'||trim(VARNAME)||'_Invalid">'||trim(put(INVALID,10.2))||'</a></td>';
	col5='<div id="'||trim(VARNAME)||'_Invalid" class="well" style="max-width:44em;"><h4>Invalid Codes:</h4><p>'||trim(INVALID_CODES)||'</p></div>';
	col6='<script>$(document).ready(function(){$("#'||trim(VARNAME)||'_Invalid").popup();});</script>';
  end;

  if PERCENT=. then do;
    col7='<td class="tdimo">'||" "||'</td>';
  end;
  else do;
    col7='<td class="tdimo">'||trim(put(PERCENT,10.2))||'</td>';
  end;

  col8 = '<td>'||trim(MIN)||'</td>';

  put '<tr>';
  put col1;
  put col19;
  put col20;
  put col21;
  put col2;
  put col3;
  put col4;
  put col5;
  put col6;
  put col7;
  put col8;
put'<td class="vimograph">';
put'	<span style="letter-spacing:-4px">';
  col9=  '<font color = " '||symget('Vcolor')||'">'||trim(GV)||' </font>';
  col16=  '<font color = " '||symget('Icolor')||'">'||trim(GI)||' </font>';
  col17=  '<font color = " '||symget('Mcolor')||'">'||trim(GM)||' </font>';
  col18=  '<font color = " '||symget('Ocolor')||'">'||trim(GO)||' </font>'; 

	put col9;
	put col16;
	put col17;
	put col18;
put'	</span>';
put'</td>';

  put'</tr>';

  if last then do;
     put '</table>';
     put "<p class='foo'>Jump to:  <a href='#IDVars' class='ft'>ID</a>&nbsp;&nbsp;<a href='#NumVars' class='ft'>Numeric</a>&nbsp;&nbsp;<a href='#CharVars'
         class='ft'>Character</a>&nbsp;&nbsp;<a href='#DateVars' class='ft'>Date(Time)</a></p></br>";

 end;

run;

***********************************;
** Create HTML file: Date/Time Vars;
***********************************;

filename vimo "&PATH./%lowcase(&DSN.)_VIMO.html" MOD;
data _null_;
  length col1-col7 $1000 ;
  file vimo;
  set vimo_datevars end=last;
  if _n_=1 then do;
    put "<p class='tlabel'>Date/Datetime/Time Variables (&date)<a name='DateVars'></a></p>";
    put '<table columns="12" cellpadding="4" cellspacing="0" >';
    put '<thead >';
    put '<tr>';
    put '<th >&nbsp; Variable Name &nbsp;</th>';
    put '<th class="varlabel">&nbsp; Variable Label &nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">V</font></u>alid<sup>*</sup>&nbsp;</th>';
    put '<th >&nbsp; % <u><font color="#800000">M</font></u>issing &nbsp;</th>';
    put '<th >&nbsp; Range &nbsp;</th>';
	col7= '<th class="vimograph">&nbsp; VIMO Graph: &nbsp;&nbsp;'||
	       '<font color="'||symget('Vcolor')||'">&#9612;</font>%Valid &nbsp;&nbsp;'||
		   '<font color="'||symget('Icolor')||'">&#9612;</font>%Invalid &nbsp;&nbsp;'||
		   '<font color="'||symget('Mcolor')||'">&#9612;</font>%Missing &nbsp;&nbsp;'||
		   '<font color="'||symget('Ocolor')||'">&#9612;</font>%Outlier &nbsp;&nbsp;'||'</th>'; 
	put col7;

    put '</tr>';
    put '</thead>';
    put '<tbody>';
  end;

  %if &FREQ = ON %then %do;  
    if  TYPE in ('Char','ID','Date')

    %if %length(&qnumvarfmtlist) >0  %then %do; or upcase(VARNAME) in (&qnumvarfmtlist) %end;  
    %if %length(&qhistovars) >0 %then %do; or lowcase(varname) in (&qhistovars) %end;
	THEN do;
			col1="<td ><a id='"||trim(lowcase(VARNAME))||"_link' class='"||trim(VARNAME)||"_popup_open' href='#"||trim(lowcase(VARNAME))||"'>"||trim(VARNAME)||"</a></td>";
		    col19="<div id='"||trim(VARNAME)||"_popup' class='well'>"||"<iframe id='"||trim(lowcase(VARNAME))||"_iframe' src='about:blank' width='500' height='500' ></iframe></div>";
			col20="<script> $('#"||trim(lowcase(VARNAME))||"_link').click(function () {$('#"||trim(lowcase(VARNAME))||"_iframe').attr('src','Freq/"||trim(lowcase(VARNAME))||".html');";
			col21=" $('#"||trim(VARNAME)|| "_popup').popup({pagecontainer: '.container',transition: 'all 0.3s'});}); </script>" ;
	end;
  %end;
  %else %do;
    col1 = '<td>'||trim(varname)||'</td>';
  %end;

  col2='<td class="varlabel">'||trim(VARLABEL)||'</td>';

  if 98 <= VALID <= 100 then col3='<td class="tdgreen" >'||trim(put(VALID,10.2))||'</td>';
  if 95 <= VALID <   98 then col3='<td class="tdorange" >'||trim(put(VALID,10.2))||'</td>';
  if 0  <= VALID <   95 then col3='<td class="tdred" >'||trim(put(VALID,10.2))||'</td>';

  if PERCENT=. then do;
    col5='<td class="tdimo">'||" "||'</td>';
  end;
  else do;
    col5='<td class="tdimo">'||trim(put(PERCENT,10.2))||'</td>';
  end;

  if strip(MIN) EQ "." and strip(MAX) EQ "." then do;
    col6 = '<td class="dtrng"></td>';
  end;
  else do;
    col6 = '<td class="dtrng">'||trim(MIN)||' - '||trim(Max)||'</td>';
  end;

  put '<tr>';
  put col1;
  put col19;
  put col20;
  put col21;
  put col2;
  put col3;
  put col5;
  put col6;
put'<td class="vimograph">';
put'	<span style="letter-spacing:-4px">';
  col7=  '<font color = " '||symget('Vcolor')||'">'||trim(GV)||' </font>';
  col16=  '<font color = " '||symget('Icolor')||'">'||trim(GI)||' </font>';
  col17=  '<font color = " '||symget('Mcolor')||'">'||trim(GM)||' </font>';
  col18=  '<font color = " '||symget('Ocolor')||'">'||trim(GO)||' </font>'; 

	put col7;
	put col16;
	put col17;
	put col18;

put'	</span>';
put'</td>';
  put'</tr>';
  if last then do;
    put '</table>';

    put "<p class='foo'>Jump to:  <a href='#IDVars' class='ft'>ID</a>&nbsp;&nbsp;<a href='#NumVars' class='ft'>Numeric</a>&nbsp;&nbsp;<a href='#CharVars'
         class='ft'>Character</a>&nbsp;&nbsp;<a href='#DateVars' class='ft'>Date(Time)</a></p></br>";
	put "<table columns='6' cellpadding='2' cellspacing='0' width='347' align='left' >";  **ok;
	      put '<tr>';
	          put "<td colspan='3' class='tdimo'><b>* Legend for % Valid </b></td>";
	      put '</tr>';
	      put '<tr>';
	                  put "<td  class='tdgreen' width='89' > 98 - 100 %</td>";
	                  put "<td  class='tdorange' width='89'> 95 - 98 %  </td>";
	                  put "<td  class='tdred' width='89'> 95 % or Less  </td>";
	          put '</tr>';
	put '</table>';
  end;
run;

filename vimo "&PATH./%lowcase(&DSN.)_VIMO.html" MOD;
data _null_;
  file vimo;
  put '<p class="date">';
  length updatedt $ 200 ;
  updatedt= put(date(), worddate.) ;
  updatedt=trim('<footnote >This page was last updated on '|| updatedt || '</footnote>');
  put updatedt ;
  put '</p>';
  put '</html>';
run;

%mend vimo_html;
