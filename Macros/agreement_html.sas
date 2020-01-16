/*========================================================================  
DataFit Toolkit - Agreement HTML macro
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
/*********************************************************************************************************************************************
 *********************************************************************************************************************************************
  | MACRO:       AGREEMENT
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Behtash Saeidi
  |
  | DATE:        2017
  |
  | DESCRIPTION: For a given dataset, this macro determines statistics for agreement between given dataset and reference dataset for variables
  |				 (date of birth and sex). The results will be an html page with tables and plots. This third program part of %agreement macro
  |
  | PARAMETERS:  
  |
  | EXAMPLES:    
  |
  | UPDATES:     2017-05-01 (Gangamma Kalappa)
  |              - Converted the program written by Behtash to a macro          
*********************************************************************************************************************************************
*********************************************************************************************************************************************/

%macro agreement_html(templib=,
						lib=,
					    ds=,
					  	ds_prefix=,
					    ds_linktype_flag=,
						ds_linktype=,
						ds_datevar=,
						ref_datevar=,
						ds_categvar=,
						ds_bydate=,
						ref_data=,
						time=,
						path=,
						report1=,
						report2=,
						report3=);
	%put &ds_bydate.; 
	%local temp_ds datevar categvar rc dsid varlst doi colname ci_pos dropvarlst
		  kappa_pos var_name_pos num_distinct_linktype kappa_start_pos upper lower distinct_linktype linktype
		  goodmatch_flag poormatch_flag dbname_exists; 

	/*************************************************************************************************************************************/
	/*Creating dataset, formats for generating HTML page*/ 
	/*----------------------------------------------------------------------------------------------------------------------------------*/
	/*Generating few local variables necessary for html files*/
	%if (&ds_prefix. eq OFF and %upcase(&ds.)  eq ALL)  %then %do;
		%let temp_ds=%sysfunc(propcase(&lib.))_all;
	%end;
	%else %if (&ds_prefix. eq OFF and %upcase(&ds.)  ne ALL)  %then %do;
		%let temp_ds=&ds.;
	%end;
	%else %do;
		%let temp_ds=%sysfunc(propcase(&ds.))_all;
	%end;

	%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0  %then %do;
		%let datevar=%substr(&ds_datevar.,%sysevalf(1+%sysfunc(findc(&ds_datevar.,"_"))));
	%end;
	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
		%let categvar=%substr(&ds_categvar.,%sysevalf(1+%sysfunc(findc(&ds_categvar.,"_"))));
	%end;

	/*Determining if Kappa Statistics exists in summary report*/
	%let dsid=%sysfunc(open(&templib..&report1.));
	%if %sysfunc(varnum(&dsid,_KAPPA_))>0 %then %do;
		%let kappa_stats_exists=1;
		%let ci_pos=%sysevalf(%sysfunc(varnum(&dsid,_KAPPA_))+1);
	%end;
	%else %do;
		%let kappa_stats_exists=0;
	%end;

	%if %sysfunc(varnum(&dsid,dbname))>0 %then %do;
		%let dbname_exists=1;
	%end;
	%else %do;
		%let dbname_exists=0;
	%end;

	/*Assigning values to few local variables based on information in Summary report dataset*/
	%if %sysfunc(varnum(&dsid,_1))>0 %then %do;
		%let poormatch_flag=1;
	%end;
	%else %let poormatch_flag=0;

	%if %sysfunc(varnum(&dsid,_2))>0 %then %do;
		%let goodmatch_flag=1;
	%end;
	%else %let goodmatch_flag=0;
	%let rc=%sysfunc(close(&dsid.));

	/*----------------------------------------------------------------------------------------------------------------------------------*/
	/*Defining formats that will be used while displaying results*/
	proc format lib=work;
		value agreement_fmt .="Missing"
								0="No Match"
								1="Poor Match*"
								2="Good Match**"
								3="Perfect Match";

		value $agreement_linkagetype "D"="Deterministic"
									"P"="Probabilistic";

		value bgcolor  .="White"
					   low-90    = '#F2DCDB'
					   90<-95   = '#FDE9D9'
					   95<-high = '#EBF1DE';

		value fgcolor .="Black"
					  low-90   = 'red'
					  90<-95      = '#E26B0A'
					  95<-high    = 'green'
					  other='black';

		value kappa_bgcolor .="White"
							-1.00-0.49 = '#F2DCDB'
						   0.49<-0.80 = '#FDE9D9'
						   0.80<-1.00 = '#EBF1DE';

		value kappa_fgcolor .="Black"
							-1.00-0.49 = 'red'
						   0.49<-0.80 = '#E26B0A'
						   0.80<-1.00 = 'green';

		value agreement_zero . = '0'
							 0 = '0'
							 other = [5.2];

		value agreement_kappa . = ' '
							 0 = '0'
							 other = [6.4];
	run;

	/*----------------------------------------------------------------------------------------------------------------------------------*/
	/*Creation of dataset that will have information that used to generate legends in html page*/
	proc format library = work 
	            cntlout = _legend;
	    select bgcolor kappa_bgcolor;
	run;

	data _legend;
		length legend $25;
	    set _legend;
		if missing(start) then delete;
		start=strip(start);
		if (strip(start) eq "LOW" and strip(end) eq "90")	 then do;
			legend="0% to less than 90%";
			legend_label="None or Minimal";
			name="Agreement rate(%)";
		end;
		else if  (strip(start) eq "-1" and strip(end) eq "0.49") 	 then do;
			legend="-1.00 to less than 0.49";
			legend_label="None or Minimal";
			name="Kappa Statistics";
		end;
		else if  (strip(start) eq "90" and strip(end) eq "95") 	 then do;
			legend="90% to less than 95%";
			legend_label="Moderate";
			name="Agreement rate(%)";
		end;
		else if  (strip(start) eq "0.49" and strip(end) eq "0.8") 	 then do;
			legend="0.49 to less than 0.80";
			legend_label="Moderate";
			name="Kappa Statistics";
		end;
		else if  (strip(start) eq "95" and strip(end) eq "HIGH") 	 then do;
			legend="Greater  than 95%";
			legend_label="Significant";
			name="Agreement rate(%)";
		end;
		else if  (strip(start) eq "0.8" and strip(end) eq "1") 	 then do;
			legend="0.8 to 1.00";
			legend_label="Significant";
			name="Kappa Statistics";
		end;
	    keep name legend legend_label ;
	run;

	/*************************************************************************************************************************************/
	/*Creation of HTML report*/
	filename odsout "&path.";
	ods listing close;
	ods tagsets.htmlpanel options(embedded_titles="no" pagebreak="no" panelrows='6' )
	                     path=odsout file="&temp_ds._agreement.html"  
	                     style=sasweb nogfootnote nogtitle ;

	goptions reset=all;


	ods escapechar='^';

	/*-----------------------------------------------------------------------------------------------------------------------------------------*/
	/*----------------------------------------- SUMMARY REPORT  -------------------------------------------------------------------------------*/
	proc sql noprint ;
		select name into : varlst separated by " " from dictionary.columns where libname="%upcase(&templib.)" and memname="SUMMARY_REPORT"
				and name in ("_0","_1","_2","_3","_99");
	quit;
	%let doi=%eval(%sysfunc(countc(&varlst.,' '))+1);

	ods tagsets.htmlpanel event=panel(start);
	title1 j=center height=15pt color=cx00669D "Agreement report ";
	title2 j=center height=13pt color=cx00669D "Comparison of %upcase(&lib.).%upcase(&temp_ds.) and %upcase(&ref_data.) ";
	title3 " ";
	title4 j=left height=11pt color=cx00669D  "Agreement level - summary:";						
	%if %sysevalf(%superq(kappa_stats_exists)=,boolean) eq 0 and &kappa_stats_exists. eq 1 %then %do;
		proc report data=&templib..&report1.  nowd headline headskip nocenter 
					style (header)=[background=cx00669D foreground=white fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0] spanrows
					style(column)=[foreground=black fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0];
			%if &dbname_exists. eq 1 %then %do;
				column &ds_linktype. dbname var_name numobs   ('Percent Agreement (%)' &varlst.) (" " _kappa_  ci  dummyvar2);
				define  &ds_linktype./"Linkage Type" group format=$agreement_linkagetype. order=formatted 
						style = [background=lightgray foreground=black verticalalign=middle fontfamily=helvetica font_size=10pt fontweight=bold];
				define  dbname/"Dataset"  group 
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold]
						style(header)=[background=lightgray foreground=black  textalign=center];
				define  var_name/"Agreement Variable"   
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold]
						style(header)=[background=lightgray foreground=black  textalign=center];
				define  numobs/"Number of Subjects in the Stratum" group format=comma12.
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold textalign=center] 
						style(header)=[background=lightgray foreground=black  textalign=center];
			%end;
			%else %do;
				column &ds_linktype.  var_name numobs   ('Percent Agreement (%)' &varlst.) (" " _kappa_  ci  dummyvar2);
				define  &ds_linktype./"Linkage Type" group format=$agreement_linkagetype. order=formatted 
						style = [background=lightgray foreground=black verticalalign=middle fontfamily=helvetica font_size=10pt fontweight=bold];
				define  var_name/"Agreement Variable"  group 
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold]
						style(header)=[background=lightgray foreground=black  textalign=center];
				define  numobs/"Number of Subjects in the Stratum" group format=comma12.
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold textalign=center] 
						style(header)=[background=lightgray foreground=black  textalign=center];
			%end;
		    %do i=1 %to &doi;
		         %let colname=%scan(&varlst.,&i," ");
				 %if &colname. eq _&perfect_match_score. %then %do;
					define  &colname./ display format=agreement_zero.
								style(column) = Header[background=bgcolor. foreground=fgcolor. font_size=9pt fontweight=bold textalign=center]
								style(header)=[background=lightgray foreground=black  textalign=center];
				%end;
				%else %do;
					define  &colname./ display format=agreement_zero.
								style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center]
								style(header)=[background=lightgray foreground=black  textalign=center];
				%end;
			%end;
			define  _kappa_/noprint group missing format=agreement_kappa.
						style(column) = Header[background=kappa_bgcolor. foreground=kappa_fgcolor. font_size=9pt fontweight=bold textalign=center];
			define  ci/"Kappa Statistics ^n ^{unicode 03ba} (95% CI)"  missing
						style(column) = Header[background=kappa_bgcolor. foreground=kappa_fgcolor. font_size=9pt fontweight=bold textalign=center]
						style(header)=[background=lightgray foreground=black  textalign=center];
			define dummyvar2 /computed noprint;
			compute dummyvar2 ;
				dummyvar2=1;	
				if _kappa_ >0.8 then 
						call define("_C&ci_pos._","style","style=[Background=#EBF1DE foreground=Green]");
				else if _kappa_ >0.49 and  _kappa_ <=0.8 then 
						call define("_C&ci_pos._","style","style=[Background=#FDE9D9 foreground=#E26B0A]");
				else if _kappa_ >-1 and  _kappa_ <=0.49 then 
						call define("_C&ci_pos._","style","style=[Background=#F2DCDB foreground=Red]");	
				else if missing(_kappa_) then 
						call define("_C&ci_pos._","style","style=[background=white foreground=Black]");	
			endcomp;
			%if (&ds_linktype_flag. eq 1) or (&poormatch_flag. eq 1) or  (&goodmatch_flag. eq 1) %then %do;
				compute after/style=[just=l font_size=7pt fontfamily=helvetica color=grey fontweight=bold fontstyle=italic];
					%if (&poormatch_flag. eq 1) %then %do;
						line 'Poor Match* : Agreement on only one date component(m,d,y)';
					%end;
					%if (&goodmatch_flag. eq 1) %then %do;
						line 'Good Match** : Agreement on two out of three date components(m,d,y)';
					%end;
					%if (&ds_linktype_flag. eq 1) %then %do;
						line 'As ds_link_type variable was null, all calculations were done assuming linkage type was Deterministic';
					%end;
				endcomp;
			%end;
		run;
		%let varlst=;
		%let doi=;
	%end;
	%else %do;
		proc report data=&templib..&report1.  nowd headline headskip nocenter 
					style (header)=[background=cx00669D foreground=white fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0] spanrows
					style(column)=[foreground=black fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0];
			%if &dbname_exists. eq 1 %then %do;
				column &ds_linktype. dbname var_name numobs   ('Percent Agreement (%)' &varlst.);
				define  &ds_linktype./"Linkage Type" group format=$agreement_linkagetype. order=formatted 
						style = [background=lightgray foreground=black verticalalign=middle fontfamily=helvetica font_size=10pt fontweight=bold];
				define  dbname/"Dataset"  group 
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold]
						style(header)=[background=lightgray foreground=black  textalign=center];
				define  var_name/"Agreement Variable"   
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold]
						style(header)=[background=lightgray foreground=black  textalign=center];
				define  numobs/"Number of Subjects in the Stratum" group format=comma12.
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold textalign=center] 
						style(header)=[background=lightgray foreground=black  textalign=center];
			%end;
			%else %do;
				column &ds_linktype. var_name numobs   ('Percent Agreement (%)' &varlst.);
				define  &ds_linktype./"Linkage Type" group format=$agreement_linkagetype. order=formatted 
						style = [background=lightgray foreground=black verticalalign=middle fontfamily=helvetica font_size=10pt fontweight=bold];
				define  var_name/"Agreement Variable"  group 
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold]
						style(header)=[background=lightgray foreground=black  textalign=center];
				define  numobs/"Number of Subjects in the Stratum" group format=comma12.
						style(column) = Header[background=white font_size=8pt foreground=black fontweight=bold textalign=center] 
						style(header)=[background=lightgray foreground=black  textalign=center];
			%end;
		    %do i=1 %to &doi;
		         %let colname=%scan(&varlst.,&i," ");
				 %if &colname. eq _&perfect_match_score. %then %do;
					define  &colname./ display format=agreement_zero.
								style(column) = Header[background=bgcolor. foreground=fgcolor. font_size=9pt fontweight=bold textalign=center]
								style(header)=[background=lightgray foreground=black  textalign=center];
				%end;
				%else %do;
					define  &colname./ display format=agreement_zero.
								style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center]
								style(header)=[background=lightgray foreground=black  textalign=center];
				%end;
			%end;
			%if (&ds_linktype_flag. eq 1) or (&poormatch_flag. eq 1) or  (&goodmatch_flag. eq 1) %then %do;
				compute after/style=[just=l font_size=7pt fontfamily=helvetica color=grey fontweight=bold fontstyle=italic];
					%if (&poormatch_flag. eq 1) %then %do;
						line 'Poor Match* : Agreement on only one date component(m,d,y)';
					%end;
					%if (&goodmatch_flag. eq 1) %then %do;
						line 'Good Match** : Agreement on two out of three date components(m,d,y)';
					%end;
					%if (&ds_linktype_flag. eq 1) %then %do;
						line 'As ds_link_type variable was null, all calculations were done assuming linkage type was Deterministic';
					%end;
				endcomp;
			%end;
		run;
		%let varlst=;
		%let doi=;
	%end;
	ods tagsets.htmlpanel event=panel(finish);
	title1 " ";
	title2;
	title4;

	/*------------------------------------------------------------------------------------------------------------------------------------*/
	/*------------------------------------- YEAR BASED REPORTS ---------------------------------------------------------------------------*/
	/*------------------------------------------------------------------------------------------------------------------------------------*/
	%if (%sysevalf(%superq(report2)=,boolean) eq 0) %then %do;
		/*Display year based report for categorical variable*/
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
			/*Clean up the year based report to retain only relevant information while displaying in html*/
			data &templib..intermediate_yr_categvar;
				set &templib..&report2.;
				where upcase(var_name)="%upcase(&ds_categvar.)";
			run;

			ods select none;
			ods output nlevels=&templib..temp;
			proc freq data=&templib..intermediate_yr_categvar nlevels;
				tables _all_;
			run;
			ods select all;

			%let dsid=%sysfunc(open(&templib..temp));
			%if %sysfunc(varnum(&dsid,NNonMissLevels))>0 %then %do;
				proc sql noprint;
					select tablevar into:dropvarlst separated by " " from &templib..temp where NNonMissLevels=0 and TableVar in ("_0","_1","_2","_3","_99");
				quit;
				data &templib..intermediate_yr_categvar;
					set &templib..intermediate_yr_categvar (drop=&dropvarlst.);
				run;
			%end;
			%let rc=%sysfunc(close(&dsid.));
			%let dropvarlst=;
			proc sql noprint ;
				select strip(name) into : varlst separated by " " from dictionary.columns where libname="%upcase(&templib.)" and lowcase(memname)="intermediate_yr_categvar"
						and name in ("_0","_1","_2","_3","_99");
			quit;
			
			/*Code to generate reprot in html for displaying year based report-Categorical variable*/
			ods tagsets.htmlpanel event=panel(start);
			title2 j=left height=11pt color=cx00669D  "%upcase(&categvar.) agreement level, based on %lowcase(&time.) year of %upcase(&ds_bydate.):";						
			%let dsid=%sysfunc(open(&templib..intermediate_yr_categvar));
			%if %sysfunc(varnum(&dsid,_1))>0 %then %do;
				%let poormatch_flag=1;
			%end;
			%else %let poormatch_flag=0;
			%if %sysfunc(varnum(&dsid,_2))>0 %then %do;
				%let goodmatch_flag=1;
			%end;
			%else %let goodmatch_flag=0;
			%let rc=%sysfunc(close(&dsid.));

			%let doi=%eval(%sysfunc(countc(&varlst.,' '))+1);
			proc report data=&templib..intermediate_yr_categvar nowd headline headskip nocenter 
					style (header)=[background=cx00669D foreground=white fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0] spanrows
					style(column)=[foreground=black fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0];
				column yr  numobs,&ds_linktype. ('Percent Agreement (%)'
					%do i=1 %to &doi;
						%let colname=%scan(&varlst.,&i," ");
						&colname.,&ds_linktype.
					%end;
					) dummyvar;;
				define yr/"Year" group center
						style(column) = [background=lightgray foreground=black  verticalalign=middle fontfamily=helvetica font_size=10pt fontweight=bold]
						style(header)=[background=lightgray foreground=black textalign=center];
				
				define numobs/"Number of Subjects" group  format=comma12.
							 style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center];
				define &ds_linktype./"" across missing format=$agreement_linkagetype. order=formatted  style(header)=[background=lightgray foreground=black textalign=center];
				
			    %do i=1 %to &doi;
					%let colname=%scan(&varlst.,&i," ");
					%let colname=%scan(%sysfunc(scan(&varlst.,&i," ")),1,",");
					%if &colname. eq _&perfect_match_score. %then %do;
						define  &colname./ display format=agreement_zero.
							style(column) = Header[background=bgcolor. foreground=fgcolor. font_size=9pt fontweight=bold textalign=center];
					%end;
					%else %do;
						define  &colname./ display format=agreement_zero.
								style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center];
					%end;		
				%end;
				define dummyvar /computed noprint;
				compute dummyvar ;
					dummyvar=1;
				endcomp;
				%if (&ds_linktype_flag. eq 1) or (&poormatch_flag. eq 1) or  (&goodmatch_flag. eq 1) %then %do;
					compute after/style=[just=l font_size=7pt fontfamily=helvetica color=grey fontweight=bold fontstyle=italic];
						%if (&poormatch_flag. eq 1) %then %do;
							line 'Poor Match* : Agreement on only one date component(m,d,y)';
						%end;
						%if (&goodmatch_flag. eq 1) %then %do;
							line 'Good Match** : Agreement on two out of three date components(m,d,y)';
						%end;
						%if (&ds_linktype_flag. eq 1) %then %do;
							line 'As ds_link_type variable was null, all calculations were done assuming linkage type was Deterministic';
						%end;
					endcomp;
				%end;
			run;
			ods tagsets.htmlpanel event=panel(finish);
			title2;
			%let varlst=;
			%let doi=;

			/*Delete temporary dataset*/
			proc datasets lib=&templib. nolist;
				delete intermediate_yr_categvar;
			run;
		%end;
		
		/*----------------------------------------------------------------------------------------------------------------------------------*/
		/*Display year based report for date variable*/
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0  %then %do;
			/*Clean up the year based report to retain only relevant information while displaying in html*/
			data &templib..intermediate_yr_datevar;
				set &templib..&report2.;
				where upcase(var_name)="%upcase(&ds_datevar.)";
			run;
			ods select none;
			ods output nlevels=&templib..temp;
			proc freq data=&templib..intermediate_yr_datevar nlevels;
				tables _all_;
			run;
			ods select all;

			%let dsid=%sysfunc(open(&templib..temp));
			%if %sysfunc(varnum(&dsid,NNonMissLevels))>0 %then %do;
				proc sql noprint;
					select tablevar into:dropvarlst separated by " " from &templib..temp where NNonMissLevels=0 and TableVar in ("_0","_1","_2","_3","_99");
				quit;
				data &templib..intermediate_yr_datevar;
					set &templib..intermediate_yr_datevar (drop=&dropvarlst.);
				run;
			%end;
			%let rc=%sysfunc(close(&dsid.));
			%let dropvarlst=;

			/*Code to generate reprot in html for displaying year based report-Date variable*/
			ods tagsets.htmlpanel event=panel(start);
			title2 j=left height=11pt color=cx00669D  "%upcase(&datevar.) agreement level, based on %lowcase(&time.) year of %upcase(&ds_bydate.):";
			proc sql noprint ;
				select strip(name) into : varlst separated by " " from dictionary.columns where libname="%upcase(&templib.)" and lowcase(memname)="intermediate_yr_datevar"
						and name in ("_0","_1","_2","_3","_99");
			quit;

			%let dsid=%sysfunc(open(&templib..intermediate_yr_datevar));
			%if %sysfunc(varnum(&dsid,_1))>0 %then %do;
				%let poormatch_flag=1;
			%end;
			%else %let poormatch_flag=0;
			%if %sysfunc(varnum(&dsid,_2))>0 %then %do;
				%let goodmatch_flag=1;
			%end;
			%else %let goodmatch_flag=0;
			%let rc=%sysfunc(close(&dsid.));

			%let doi=%eval(%sysfunc(countc(&varlst.,' '))+1);
			proc report data=&templib..intermediate_yr_datevar  nowd headline headskip nocenter 
					style (header)=[background=cx00669D foreground=white fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0] spanrows 
					style(column)=[foreground=black fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0];
				column (' ' yr) numobs,&ds_linktype. ('Percent Agreement (%)'
					%do i=1 %to &doi;
						%let colname=%scan(&varlst.,&i," ");
						&colname.,&ds_linktype.
					%end;
					) dummyvar;;
				define yr/"Year" group center
						style = [background=lightgray foreground=black  verticalalign=middle fontfamily=helvetica font_size=10pt fontweight=bold ] 
						style(header)=[background=lightgray foreground=black  textalign=center ];
				define numobs/"Number of Subjects" group  format=comma12.
							 style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center];
				define &ds_linktype./"" across missing format=$agreement_linkagetype. order=formatted style(header)=[background=lightgray foreground=black  textalign=center ];

				%do i=1 %to &doi;
					%let colname=%scan(&varlst.,&i," ");
					%let colname=%scan(%sysfunc(scan(&varlst.,&i," ")),1,",");
					%if &colname. eq _&perfect_match_score. %then %do;
						define  &colname./ display format=agreement_zero.
							style(column) = Header[background=bgcolor. foreground=fgcolor. font_size=9pt fontweight=bold textalign=center];
					%end;
					%else %do;
						define  &colname./ display format=agreement_zero.
							style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center];
					%end;		
				%end;
				define dummyvar /computed noprint;
				compute dummyvar ;
					dummyvar=1;
				endcomp;
				%if (&ds_linktype_flag. eq 1) or (&poormatch_flag. eq 1) or  (&goodmatch_flag. eq 1) %then %do;
					compute after/style=[just=l font_size=7pt fontfamily=helvetica color=grey fontweight=bold fontstyle=italic];
						%if (&poormatch_flag. eq 1) %then %do;
							line 'Poor Match* : Agreement on only one date component(m,d,y)';
						%end;
						%if (&goodmatch_flag. eq 1) %then %do;
							line 'Good Match** : Agreement on two out of three date components(m,d,y)';
						%end;
						%if (&ds_linktype_flag. eq 1) %then %do;
							line 'As ds_link_type variable was null, all calculations were done assuming linkage type was Deterministic';
						%end;
					endcomp;
				%end;
			run;
			ods tagsets.htmlpanel event=panel(finish);
			title2;
			%let varlst=;
			%let doi=;

			/*Delete temporary dataset*/
			proc datasets lib=&templib. nolist;
				delete intermediate_yr_datevar;
			run;
		%end;

		/*-------------------------------------------------------------------------------------*/
		/*Display year based Kappa statistics for categorical variable*/
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
			%if %sysevalf(%superq(kappa_stats_exists)=,boolean) eq 0 and &kappa_stats_exists. eq 1 %then %do;
				/*Clean up the year based report to retain only relevant information while displaying in html*/
				proc sql noprint ;
					select strip(name) into : varlst separated by " " from dictionary.columns where libname="%upcase(&templib.)" and memname="%upcase(&report2.)"
							and name not in ("numobs","_0","_1","_2","_3","_99");
				quit;

				data &templib..intermediate_kappa_stats;
					set &templib..&report2. (keep=&varlst.);
					where upcase(var_name)="%upcase(&ds_categvar.)";
				run;
				ods select none;
				ods output nlevels=&templib..temp;
				proc freq data=&templib..intermediate_kappa_stats nlevels;
					tables _all_;
				run;
				ods select all;

				%let dsid=%sysfunc(open(&templib..temp));
				%if %sysfunc(varnum(&dsid,NNonMissLevels))>0 %then %do;
					proc sql noprint;
						select tablevar into:dropvarlst separated by " " from &templib..temp where NNonMissLevels=0 and TableVar in ("N","NMISS");
					quit;
					data &templib..intermediate_kappa_stats;
						set &templib..intermediate_kappa_stats (drop=&dropvarlst.);
					run;
				%end;
				%let rc=%sysfunc(close(&dsid.));
				%let dropvarlst=;
				%let varlst=;

				proc sql noprint ;
					select count(distinct &ds_linktype.) into : num_distinct_linktype from &templib..intermediate_kappa_stats;
				quit;

				/*Determining the variable position of kappa statistics in dataset*/
				%let dsid=%sysfunc(open(&templib..intermediate_kappa_stats));
				%if %sysfunc(varnum(&dsid,_KAPPA_))>0 %then %do;
					%let kappa_pos=%sysfunc(varnum(&dsid,_KAPPA_));
					%let var_name_pos=%sysfunc(varnum(&dsid,var_name));
					%let kappa_start_pos=%sysevalf(1+((&kappa_pos.-&var_name_pos.-1)*&num_distinct_linktype.)+1);
					%let ci_pos=%sysevalf(&kappa_start_pos.+&num_distinct_linktype.);
				%end;
				%let rc=%sysfunc(close(&dsid.));

				/*Code to generate report in html for displaying year based Kappa statistics-Categorical variable*/
				ods tagsets.htmlpanel event=panel(start);
				title2 j=left height=11pt color=cx00669D  "%upcase(&categvar.) kappa statistics, based on %lowcase(&time.) year of %upcase(&ds_bydate.):";		
				proc report data=&templib..intermediate_kappa_stats nowd headline headskip nocenter
					style (header)=[background=cx00669D foreground=white fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0] spanrows 
					style(column)=[foreground=black fontfamily=helvetica font_size=10pt bordercolor=darkgray borderwidth=0.01 borderspacing=0];
					column yr  n,&ds_linktype. nmiss,&ds_linktype.  _kappa_,&ds_linktype. ci,&ds_linktype. dummyvar;

					define yr/"Year" group center
						style = [background=lightgray foreground=black verticalalign=middle fontfamily=helvetica font_size=10pt fontweight=bold];
					define &ds_linktype./"" across missing format=$agreement_linkagetype. order=formatted style(header)=[background=lightgray foreground=black  textalign=center ];
					define n/group format=comma12.
							 style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center];
					define nmiss/group format=comma12.
							 style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center];
					define _kappa_/ noprint group missing format=agreement_kappa. 
							 style(column) = Header[background=white foreground=black font_size=9pt fontweight=bold textalign=center];
					define ci/"Kappa Statistics  ^n ^{unicode 03ba} (95% CI)"  missing
						style(column) = Header[background=kappa_bgcolor. foreground=kappa_fgcolor. font_size=9pt fontweight=bold textalign=center];
					define dummyvar /computed noprint;
					compute dummyvar ;
						dummyvar=1;
						%do i=1 %to &num_distinct_linktype.;
							%if &i. ne 1 %then %do;
								%let ci_pos=%sysevalf(&ci_pos.+1);
								%let kappa_start_pos=%sysevalf(&kappa_start_pos.+1);
							%end;	
							if _C&kappa_start_pos._ >0.8 then 
									call define("_C&ci_pos._","style","style=[Background=#EBF1DE foreground=Green]");
							else if _C&kappa_start_pos._ >0.49 and  _kappa_ <=0.8 then 
									call define("_C&ci_pos._","style","style=[Background=#FDE9D9 foreground=#E26B0A]");
							else if _C&kappa_start_pos._ >-1 and  _kappa_ <=0.49 then 
									call define("_C&ci_pos._","style","style=[Background=#F2DCDB foreground=Red]");	
							else if missing(_C&kappa_start_pos._) then 
									call define("_C&kappa_start_pos._","style","style=[background=white foreground=Black]");
						%end;	
					endcomp;
				run;
				ods tagsets.htmlpanel event=panel(finish);
				title2;

				/*Delete temporary dataset*/
				proc datasets lib=&templib. nolist;
					delete intermediate_kappa_stats;
				run;
			%end;
		%end;
	%end;

	/*---------------------------------------------------------------------------------------------------------------------------------*/
	/*Generate legends in html page*/
	ods tagsets.htmlpanel event=panel(start);
	proc report data = _legend nowd headline headskip  nocenter 
					style (header)=[background=lightgray foreground=black fontfamily=helvetica font_size=8pt bordercolor=darkgray borderwidth=0.01 borderspacing=0] spanrows
					style(column)=[foreground=black fontfamily=helvetica font_size=8pt bordercolor=darkgray borderwidth=0.01 borderspacing=0];
	    column legend_label  legend,name dummyvar;
	    define legend_label /"Legend for agreement statistics" group order=data;
	    define name   /"" across ; 
		define legend   /"" display ;
		define dummyvar/noprint;
		compute dummyvar;
			dummyvar=1;
			if legend_label eq "None or Minimal" then do;
				call define("_C1_","style","style=[Background=#F2DCDB foreground=red verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
				call define("_C2_","style","style=[Background=#F2DCDB foreground=red verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
				call define("_C3_","style","style=[Background=#F2DCDB foreground=red verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
			end;
			else if legend_label eq "Moderate" then do;
				call define("_C1_","style","style=[Background=#FDE9D9 foreground=#E26B0A verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
				call define("_C2_","style","style=[Background=#FDE9D9 foreground=#E26B0A verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
				call define("_C3_","style","style=[Background=#FDE9D9 foreground=#E26B0A verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
			end;
			else if legend_label eq "Significant" then do;
				call define("_C1_","style","style=[Background=#EBF1DE foreground=green verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
				call define("_C2_","style","style=[Background=#EBF1DE  foreground=green verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
				call define("_C3_","style","style=[Background=#EBF1DE  foreground=green verticalalign=middle fontfamily=helvetica font_size=7pt fontweight=bold]");
			end;
		endcomp;
	run;

	proc datasets lib=work nolist;
		delete _legend;
	run;
	ods tagsets.htmlpanel event=panel(finish);

	/*-------------------------------------------------------------------------------------*/
	/*Generate Bland-Altman plot for date variable*/
	%if (%sysevalf(%superq(report3)=,boolean) eq 0) %then %do;
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			proc sql noprint ;
				select mean(datevar_diff)-2*std(datevar_diff), mean(datevar_diff)+2*std(datevar_diff)
					into :lower, :upper
					from &templib..&report3.;
				select distinct &ds_linktype.,count(distinct &ds_linktype.) into : distinct_linktype separated by " ",
																		:num_distinct_linktype from &templib..&report3.;
			quit; 
			options nocenter;
			ods tagsets.htmlpanel event=panel(start) ;
			title2 j=left height=11pt color=cx00669D  "Bland-Altman plot for %upcase(&datevar.)";
			%do i=1 %to &num_distinct_linktype.;
				%let linktype=%sysfunc(strip(%scan(&distinct_linktype.,&i," ")));
				ods graphics on/imagemap imagename="&temp_ds._bland_altman_&linktype." imagefmt=png  ;
				proc sgplot data=&templib..&report3. noborder ;
					scatter x=datevar_yr y=datevar_diff/ markerattrs=(symbol=circle size=5px color=blue); 
					xaxis label="Average of the two dates" fitpolicy=rotatethin labelattrs=( weight=bold color="cx00669D");
					yaxis label="Differences of the two dates in years (&ref_datevar.-&ds_datevar.)" fitpolicy=thin labelpos=center labelattrs=( weight=bold color="cx00669D");
					refline 0 &upper. &lower. / label =("Zero bias line" "95% upper limit" "95% lower limit") labelattrs=( size=7pt color="cx00669D" weight=bold);
					%if %upcase(&linktype.) eq D %then %do;
						inset "Deterministic linkage"/position=top textattrs=(size=9pt color=cx00669D weight=bold);
					%end;
					%else %do;
						inset "Probabilistic linkage"/position=top textattrs=(size=9pt color=cx00669D weight=bold);
					%end;
					where upcase(&ds_linktype.)= "%upcase(&linktype.)";
				run;
				quit;
				ods graphics off;
			%end;
			options center;
			ods tagsets.htmlpanel event=panel(finish);
			title2;
		%end;
	%end;

	footnote3 j=right height=8pt color=grey "This report was updated on %sysfunc(left(%qsysfunc(date(),worddate18.)))";
	
	ods tagsets.htmlpanel close;
	ods listing;
	filename odsout clear;
	title;
	title2;
	title3;
	title4;
	footnote3;
%mend agreement_html;




