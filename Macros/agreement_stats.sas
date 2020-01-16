/*========================================================================  
DataFit Toolkit - Agreement Stats macro
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
  |				 (date of birth and sex). The results will be an html page with tables and plots. This second program part of %agreement macro
  |
  | PARAMETERS:  
  |
  | EXAMPLES:    
  |
  | UPDATES:     2017-05-01 (Gangamma Kalappa)
  |              - Converted the program written by Behtash to a macro          
*********************************************************************************************************************************************
*********************************************************************************************************************************************/


/********************************************************************************************************************************************/
/*Macro to generate summary statistics*/
%macro summaryStats (templib=,
					 ds_datevar=,
				     ds_categvar=,
				     ds_linktype=,
				     ref_categvar=,
				     ref_data=,
				     ds_prefix=,
				     ds_ori=);
	/*Check if atleast there is one record with comparable categ variable*/
	/*%local distinct_categvar_refdb;
	%let distinct_categvar_refdb=0;
	%if %sysevalf(%superq(ref_categvar)=,boolean) eq 0 %then %do;
		proc sql noprint;
			select count(distinct &ref_categvar.) into :distinct_categvar_refdb from &templib..&ref_data.;
		quit;
	%end;*/

	proc sort data=&templib..percent_agreement out=&templib..temp;
		%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
			by dbname &ds_linktype.;
		%end;
		%else %do; /*When ds_prefiX=ON or OFF and ds not equal to ALL*/
			by &ds_linktype.;
		%end;
	run;

	%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
		proc freq data=&templib..temp noprint;
			tables datevar_score/ missing outcum out=&templib..freqby_linktype_datevar ;
			%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
				by dbname &ds_linktype.;
			%end;
			%else %do;/*When ds_prefiX=ON or OFF and ds not equal to ALL*/
				by &ds_linktype.;
			%end;
		run;

		proc sql noprint;
			create table &templib..intermediate as 
			%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
				select *,max(cum_freq) as numobs from &templib..freqby_linktype_datevar group by dbname,&ds_linktype.;
			%end;
			%else %do;/*When ds_prefiX=ON or OFF and ds not equal to ALL*/
				select *,max(cum_freq) as numobs from &templib..freqby_linktype_datevar group by &ds_linktype.;
			%end;	
		quit;

		data &templib..freqby_linktype_datevar;
			set &templib..intermediate (drop=cum_freq);
			length var_name $32;
			var_name=strip(upcase(symget('ds_datevar')));
			/*Retaining 3 decimal points only*/
			PERCENT=floor(PERCENT/0.001)*0.001;
			rename datevar_score =score;
		run;
	%end;
		
	/*Percent agreement and Kappa co-efficient*/
	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
		/*Percent agreement categvar - by linktype*/
		proc freq data=&templib..temp noprint;
			tables categvar_score/ missing outcum out=&templib..freqby_linktype_categvar;
			%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
				by dbname &ds_linktype.;
			%end;
			%else %do;/*When ds_prefiX=ON or OFF and ds not equal to ALL*/
				by &ds_linktype.;
			%end;
		run;

		proc sql noprint;
			create table &templib..intermediate as 
			%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
				select *,max(cum_freq) as numobs from &templib..freqby_linktype_categvar group by dbname,&ds_linktype.;
			%end;
			%else %do;/*When ds_prefiX=ON or OFF and ds not equal to ALL*/
				select *,max(cum_freq) as numobs from &templib..freqby_linktype_categvar group by &ds_linktype.;
			%end;	
		quit;

		data &templib..freqby_linktype_categvar;
			set &templib..intermediate (drop=cum_freq);
			length var_name $32;
			var_name=strip(upcase(symget('ds_categvar')));
			/*Retaining 3 decimal points only*/
			PERCENT=floor(PERCENT/0.001)*0.001;
			rename categvar_score =score;
		run;

		/*Kappa co-efficient*/
		%if (&distinct_categvar_refdb. le 2) %then %do;
			proc sort data=&templib..kappaCoeff; 
				%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
					by dbname &ds_linktype.;
				%end;
				%else %do;/*When ds_prefiX=ON or OFF and ds not equal to ALL*/
					by &ds_linktype.;
				%end;
			run;

			proc freq data=&templib..kappaCoeff noprint ; 
				table &ds_categvar.*&ref_categvar. / list AGREE;
				%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
					output out=&templib..kappa_linktype(keep=dbname &ds_linktype. n nmiss _kappa_ l_kappa u_kappa) agree nmiss;
					by dbname &ds_linktype.;
				%end;
				%else %do;/*When ds_prefiX=ON or OFF and ds not equal to ALL*/
					output out=&templib..kappa_linktype(keep= &ds_linktype. n nmiss _kappa_ l_kappa u_kappa) agree nmiss;
					by &ds_linktype.;
				%end;
			run;

			/*Keeping only upto two decimal places*/
			data &templib..kappa_linktype;
				set &templib..kappa_linktype;
				length ci $30 ;
				_kappa_=floor(_kappa_/0.0001)*0.0001;
				l_kappa=floor(l_kappa/0.0001)*0.0001;
				u_kappa=floor(u_kappa/0.0001)*0.0001;
				ci=put(_kappa_,z6.4)||" ("||put(l_kappa,z6.4)||", "||put(u_kappa,z6.4)||")";
			run;
		%end;
	%end;
%mend summaryStats;


/********************************************************************************************************************************************/
/*Macro to generate year based statistics*/
%macro yrBasedStats (templib=,
					 ds_datevar=,
				     ds_categvar=,
				     ds_linktype=,
				     ref_categvar=,
				     ref_data=,
				     ds_prefix=,
				     ds_ori=);
	/*Check if atleast there is one record with comparable categ variable*/
	/*%local distinct_categvar_refdb;
	%let distinct_categvar_refdb=0;
	%if %sysevalf(%superq(ref_categvar)=,boolean) eq 0 %then %do;
		proc sql noprint;
			select count(distinct &ref_categvar.) into :distinct_categvar_refdb from &templib..&ref_data.;
		quit;
	%end;*/

	proc sort data=&templib..percent_agreement out=&templib..temp1;
		by yr &ds_linktype.;
	run;

	/*Percent agreement datevar - by linktype*/
	%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
		proc freq data=&templib..temp1 noprint;
			tables datevar_score/ missing outcum out=&templib..freqby_yrlinktype_datevar ;
			by yr &ds_linktype.;
		run;
		
		proc sql noprint;
			create table &templib..intermediate as 
			select *,max(cum_freq) as numobs from &templib..freqby_yrlinktype_datevar group by yr,&ds_linktype.;
		quit;

		data &templib..freqby_yrlinktype_datevar ;
			set &templib..intermediate (drop=cum_freq);
			length var_name $32;
			var_name=strip(upcase(symget('ds_datevar')));
			/*Retaining 3 decimal points only*/
			PERCENT=floor(PERCENT/0.001)*0.001;
			rename datevar_score =score;
		run;
	%end;

	/*Percent agreement and Kappa co-efficient*/
	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
		/*Percent agreement categvar - by linktype*/
		proc freq data=&templib..temp1 noprint;
			tables categvar_score/ missing outcum  out=&templib..freqby_yrlinktype_categvar;
			by yr &ds_linktype.;
		run;

		proc sql noprint;
			create table &templib..intermediate as 
			select *,max(cum_freq) as numobs from &templib..freqby_yrlinktype_categvar group by yr,&ds_linktype.;
		quit;

		data &templib..freqby_yrlinktype_categvar;
			set &templib..intermediate (drop=cum_freq);
			length var_name $32;
			var_name=strip(upcase(symget('ds_categvar')));
			/*Retaining 3 decimal points only*/
			PERCENT=floor(PERCENT/0.001)*0.001;
			rename categvar_score =score;
		run;

		/*Kappa co-efficient*/
		%if (&distinct_categvar_refdb. le 2) %then %do;
			proc sort data=&templib..kappaCoeff; 
				by yr &ds_linktype.; 
			run;

			proc freq data=&templib..kappaCoeff noprint ; 
				table &ds_categvar.*&ref_categvar. / list AGREE;
				output out=&templib..kappa_yr_linktype(keep=yr &ds_linktype. n nmiss _kappa_ l_kappa u_kappa) agree nmiss;
				by yr &ds_linktype.;
			run;

			data &templib..kappa_yr_linktype;
				set &templib..kappa_yr_linktype;
				/*Keeping only upto two decimal places*/
				/*Ceil if value less than zero*/
				/*_kappa_=ifn(_kappa_<0,ceil(_kappa_/0.01),floor(_kappa_/0.01))*0.01;*/
				length ci $30 ;
				_kappa_=floor(_kappa_/0.0001)*0.0001;
				l_kappa=floor(l_kappa/0.0001)*0.0001;
				u_kappa=floor(u_kappa/0.0001)*0.0001;
				ci=put(_kappa_,z6.4)||" ("||put(l_kappa,z6.4)||", "||put(u_kappa,z6.4)||")";
			run;
		%end;
	%end;
%mend yrBasedStats;



/********************************************************************************************************************************************/
/*Macro to generate summary report -Generate report datasets for creating final html report*/
%macro summaryReport (templib=,
					 ds_datevar=,
				     ds_categvar=,
				     ds_linktype=,
					 ref_categvar=,
					 ref_data=,
				     ds_prefix=,
				     ds_ori=);
	/*Check if atleast there is one record with comparable categ variable*/
	/*%local distinct_categvar_refdb;
	%let distinct_categvar_refdb=0;
	%if %sysevalf(%superq(ref_categvar)=,boolean) eq 0 %then %do;
		proc sql noprint;
			select count(distinct &ref_categvar.) into :distinct_categvar_refdb from &templib..&ref_data.;
		quit;
	%end;*/

	data &templib..intermediate_summary_report (keep=
					%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
						&ds_linktype. dbname var_name numobs score percent score_label new_score
					%end;
					%else %do;
						&ds_linktype. var_name numobs score percent score_label new_score
					%end;
				);
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  and %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			set &templib..freqby_linktype_datevar &templib..freqby_linktype_categvar;
		%end;
		%else %if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
			set  &templib..freqby_linktype_categvar;
		%end;
		%else %if %sysevalf(%superq(ds_datevar)=,boolean) eq 0  %then %do;
			set  &templib..freqby_linktype_datevar;
		%end;
		length score_label $14 new_score $3;
		if missing(score) then do;
			score_label="Missing";
			new_score="_99";
		end;
		else do;
			if score=0 then score_label="No Match";
			else if score=1 then score_label="Poor Match*";
			else if score=2 then score_label="Good Match**";
			else if score=3 then score_label="Perfect Match";
			new_score="_"||strip(put(score,2.));
		end;
	run;

	%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
		proc sort data=&templib..intermediate_summary_report out=&templib..temp;
			by &ds_linktype. score  var_name dbname numobs ;
		run;
		proc sort data=&templib..temp out=&templib..intermediate_summary_report;
			by &ds_linktype. var_name dbname numobs;
		run;
		proc transpose data=&templib..intermediate_summary_report out=&templib..temp(drop=_Name_ _label_);
			id new_score;
			idlabel score_label;
			var percent;
			by &ds_linktype. var_name dbname numobs;
		run;	
	%end;
	%else %do;	
		proc sort data=&templib..intermediate_summary_report out=&templib..temp;
			by &ds_linktype. score var_name numobs ;
		run;
		proc sort data=&templib..temp out=&templib..intermediate_summary_report;
			by &ds_linktype. var_name numobs;
		run;

		proc transpose data=&templib..intermediate_summary_report out=&templib..temp(drop=_Name_ _label_);
			id new_score;
			idlabel score_label;
			var percent;
			by &ds_linktype. var_name numobs;
		run;
	%end;

	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
		%if &distinct_categvar_refdb. gt 2 %then %do;
			proc sort data=&templib..temp out=&templib..summary_report;
				%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
					by &ds_linktype. var_name dbname;
				%end;
				%else %do; /*When ds_prefiX=ON or OFF and ds not equal to ALL*/
					by &ds_linktype. var_name;
				%end;
			run;
		%end;
		%else %do;
			proc sort data=&templib..temp out=&templib..intermediate_summary_report;
				%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
					by &ds_linktype. var_name dbname;
				%end;
				%else %do; /*When ds_prefiX=ON or OFF and ds not equal to ALL*/
					by &ds_linktype. var_name;
				%end;
			run;

			data &templib..kappa_linktype;
				set &templib..kappa_linktype;
				length var_name $32;
				var_name=strip(upcase(symget('ds_categvar')));
			run;

			proc sort data=&templib..kappa_linktype;
				%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
					by &ds_linktype. var_name dbname;
				%end;
				%else %do; /*When ds_prefiX=ON or OFF and ds not equal to ALL*/
					by &ds_linktype. var_name;
				%end;
			run;

			data &templib..summary_report (drop=n nmiss l_kappa u_kappa);
				merge &templib..intermediate_summary_report &templib..kappa_linktype;
				%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
					by &ds_linktype. var_name dbname;
				%end;
				%else %do; /*When ds_prefiX=ON or OFF and ds not equal to ALL*/
					by &ds_linktype. var_name;
				%end;
			run;
		%end;
	%end;
	%else %do;
		proc sort data=&templib..temp out=&templib..summary_report;
			%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) eq ALL) %then %do;
				by &ds_linktype. var_name dbname;
			%end;
			%else %do; /*When ds_prefiX=ON or OFF and ds not equal to ALL*/
				by &ds_linktype. var_name;
			%end;
		run;
	%end;
%mend summaryReport;


/********************************************************************************************************************************************/
/*Macro to generate year based report -Generate report datasets for creating final html report*/
%macro yrBasedReport (templib=,
					 ds_datevar=,
				     ds_categvar=,
				     ds_linktype=,
					 ref_categvar=,
					 ref_data=,
				     ds_prefix=,
				     ds_ori=);
	/*Check if atleast there is one record with comparable categ variable*/
	/*%local distinct_categvar_refdb;
	%let distinct_categvar_refdb=0;
	%if %sysevalf(%superq(ref_categvar)=,boolean) eq 0 %then %do;
		proc sql noprint;
			select count(distinct &ref_categvar.) into :distinct_categvar_refdb from &templib..&ref_data.;
		quit;
	%end;*/

	data &templib..intermediate_yr_summary_report (keep=yr &ds_linktype. var_name  numobs score percent score_label new_score);
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  and %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			set &templib..freqby_yrlinktype_datevar &templib..freqby_yrlinktype_categvar ;
		%end;
		%else %if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
			set  &templib..freqby_yrlinktype_categvar;
		%end;
		%else %if %sysevalf(%superq(ds_datevar)=,boolean) eq 0  %then %do;
			set  &templib..freqby_yrlinktype_datevar;
		%end;
		length score_label $14 new_score $3;
		if missing(score) then do;
			score_label="Missing";
			new_score="_99";
		end;
		else do;
			if score=0 then score_label="No Match";
			else if score=1 then score_label="Poor Match*";
			else if score=2 then score_label="Good Match**";
			else if score=3 then score_label="Perfect Match";
			new_score="_"||strip(put(score,2.));
		end;
	run;

	proc sort data=&templib..intermediate_yr_summary_report out=&templib..temp;
		by yr &ds_linktype. score var_name ;
	run;

	proc sort data=&templib..temp out=&templib..intermediate_yr_summary_report;
		by yr &ds_linktype. var_name numobs;
	run;

	proc transpose data=&templib..intermediate_yr_summary_report out=&templib..temp(drop=_Name_ _label_);
		id new_score;
		idlabel score_label;
		var percent;
		by yr &ds_linktype. var_name numobs;
	run;

	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
		%if &distinct_categvar_refdb. gt 2 %then %do;
			proc sort data=&templib..temp out=&templib..yr_based_report;
				by yr &ds_linktype. var_name;
			run;
		%end;
		%else %do;
			proc sort data=&templib..temp out=&templib..intermediate_yr_summary_report;
				by yr &ds_linktype. var_name;
			run;

			data &templib..kappa_yr_linktype;
				set &templib..kappa_yr_linktype;
				length var_name $32;
				var_name=strip(upcase(symget('ds_categvar')));
			run;

			proc sort data=&templib..kappa_yr_linktype;
				by yr &ds_linktype. var_name;
			run;

			data &templib..yr_based_report;
				merge &templib..intermediate_yr_summary_report &templib..kappa_yr_linktype;
				by yr &ds_linktype. var_name;
			run;
		%end;
	%end;
	%else %do;
		proc sort data=&templib..temp out=&templib..yr_based_report;
			by yr &ds_linktype. var_name;
		run;
	%end;

	data &templib..yr_based_report;
		set &templib..yr_based_report (drop=l_kappa u_kappa);
		by yr &ds_linktype. var_name;
		label N="Number of Subjects";
	run;
%mend yrBasedReport;


/********************************************************************************************************************************************/
/*Macro -Main macro which calls different agreement methods */
%macro agreement_stats(templib=,
						ds=,
						ds_ori=,
						ds_prefix=,
						ds_linktype=,
						ds_byvar=,
						ds_bydate=,
						ds_datevar=,
						ds_categvar=,
						ref_data=,
						ref_byvar=,
						ref_datevar=,
						ref_categvar=,
						time=
						);
	%local distinct_categvar_refdb distinct_categvar_ds dsid rc count_categvar;

	/*Check if atleast there is one record with comparable categ variable*/
	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
		%let count_categvar=0;
		proc sql noprint;
			select count(&ds_categvar.) into:count_categvar from &templib..&ds. 
					where %sysfunc(strip(%upcase(&ds_categvar.))) in (select distinct &ref_categvar. 
																				from  &templib..&ref_data. where not missing(&ref_categvar.));
		quit;
		%if &count_categvar. eq 0 %then %do;
			%put;
		    %put ERROR:Variable "&ds_categvar" in input dataset "&templib..&ds" do not have values comparable to variable "&ref_categvar" of reference dataset "&ref_data.";
			%put NOTE: Macro will be terminated;
		    %put;
			%symdel perfect_match_score;
		    %abort;
		%end;

		%let distinct_categvar_refdb=0;
		proc sql noprint;
			select count(distinct &ref_categvar.) into :distinct_categvar_refdb from &templib..&ref_data.;
		quit;
		%if &distinct_categvar_refdb. gt 2 %then %do;
			%put;
			%put WARNING:Kappa co-efficient can  be calculated only for binary variable.&ref_categvar. in reference dataset &ref_data. has more than 2 values  ;
			%put WARNING:Please note that due to above reason kappa co-efficient will not be calculated;
			%put;
		%end;
	%end;

	/*------------------------------------------------------------------------------------------------------------------------------------*/
	/*Merge cleaned input dataset with cleaned reference dataset*/
	data &templib..merged_inds_refds;
		merge &templib..&ds. (in=a) &templib..&ref_data. (in=b );
		by &ref_byvar.;
		if a and b then output &templib..merged_inds_refds;
	run;


	/*------------------------------------------------------------------------------------------------------------------------------------*/
	/*Preparing datasets for calculating summary statistics*/
	/*Bland-Altman Method*/
	%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
		data &templib..bland_altman_app;
			set &templib..merged_inds_refds;
			datevar_diff=(&ref_datevar. - &ds_datevar.)/365;
			datevar_mean = (&ref_datevar. + &ds_datevar.)/2;
			format datevar_mean date9.;
			datevar_yr=year(datevar_mean);
		run;
	%end;

	/*Calculate agreement score for date variable and categorical variable*/
	data &templib..percent_agreement;
		set &templib..merged_inds_refds;
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			datevar_score=0;
			if missing(&ds_datevar.) or missing(&ref_datevar.) then call missing(datevar_score);
		 	if year(&ds_datevar.) eq year(&ref_datevar.) then datevar_score+1;
			if month(&ds_datevar.) eq month(&ref_datevar.) then datevar_score+1;
			if day(&ds_datevar.) eq day(&ref_datevar.) then datevar_score+1;
		%end;
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
			categvar_score=0;
			if missing(&ds_categvar.) or missing(&ref_categvar.) then call missing(categvar_score);
		 	if strip(&ds_categvar.) eq strip(&ref_categvar.) then categvar_score=3;
		%end;
	run;

	/*Preparing dataset for calculating Kappa co-efficients*/
	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
		%if &distinct_categvar_refdb. le 2 %then %do;
			proc sql noprint;
				select count(distinct &ds_categvar.) into :distinct_categvar_ds from &templib..merged_inds_refds;
			quit;
			%if &distinct_categvar_ds. gt 2 %then %do;
				/*As kappa co-efficient can only be calculated for binary values if in input dataset we have more than 2 
				distinct values for the variable; then blank out the values which do not correspond to value in reference dataset*/
				proc sql noprint;
					create table &templib..part1 as
						select * from &templib..merged_inds_refds where strip(%upcase(&ds_categvar.)) in 
												(select distinct strip(%upcase(&ref_categvar.)) from &templib..&ref_data.);
					create table &templib..part2 as
						select * from &templib..merged_inds_refds where strip(%upcase(&ds_categvar.)) not in 
												(select distinct strip(%upcase(&ref_categvar.)) from &templib..&ref_data.);
				quit;

				data &templib..part2;
					set &templib..part2;
					call missing(&ds_categvar.);
				run;

				data &templib..kappaCoeff;
					set &templib..part1 &templib..part2;
				run;
			%end;
			%else %do;
				data &templib..kappaCoeff;
					set &templib..merged_inds_refds;
				run;
			%end;
		%end;
	%end;

	/*------------------------------------------------------------------------------------------------------------------------------------*/
	/*Macro call to generate Summary Statistics*/
	%summaryStats (templib=&templib.,
				   ds_datevar=&ds_datevar.,
				   ds_categvar=&ds_categvar.,
				   ds_linktype=&ds_linktype.,
				   ref_categvar=&ref_categvar.,
				   ref_data=&ref_data.,
				   ds_prefix=&ds_prefix.,
				   ds_ori=&ds_ori.);

	/*Macro call to generate Summary Statistics Report*/
	/*Generate summary report datasets for creating final html report*/
	%summaryReport(templib=&templib.,
				   ds_datevar=&ds_datevar.,
				   ds_categvar=&ds_categvar.,
				   ds_linktype=&ds_linktype.,
				   ref_categvar=&ref_categvar.,
				   ref_data=&ref_data.,
				   ds_prefix=&ds_prefix.,
				   ds_ori=&ds_ori.)
		

	/*------------------------------------------------------------------------------------------------------------------------------------*/
	/*Macro call to generate Year Based Statistics*/
	/*Year based statistics will not be generated if user has passsed ds value as ALL and ds_prefix=OFF*/
	%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds_ori.) ne ALL) or (%upcase(&ds_prefix.) eq ON) %then %do;
		%let dsid=%sysfunc(open(&templib..merged_inds_refds));
		%if %sysfunc(varnum(&dsid., yr)) ne 0 %then %do;
			%let rc=%sysfunc(close(&dsid));
			%yrBasedStats (templib=&templib.,
						   ds_datevar=&ds_datevar.,
						   ds_categvar=&ds_categvar.,
						   ds_linktype=&ds_linktype.,
						   ref_categvar=&ref_categvar.,
						   ref_data=&ref_data.,
						   ds_prefix=&ds_prefix.,
						   ds_ori=&ds_ori.);

			/*Macro call to generate Year based Statistics Report*/
			/*Generate year based report datasets for creating final html report*/
			%yrBasedReport(templib=&templib.,
						   ds_datevar=&ds_datevar.,
						   ds_categvar=&ds_categvar.,
						   ds_linktype=&ds_linktype.,
						   ref_categvar=&ref_categvar.,
						   ref_data=&ref_data.,
						   ds_prefix=&ds_prefix.,
						   ds_ori=&ds_ori.)
		%end;
		%else %do;
			%let rc=%sysfunc(close(&dsid));
		%end;
	%end;

	/*------------------------------------------------------------------------------------------------------------------------------------*/
	/*Delete all temporary/intermediate datasets created*/
	proc datasets lib=&templib. nolist;
		delete freqby_linktype_datevar freqby_linktype_categvar  freqby_yrlinktype_datevar freqby_yrlinktype_categvar
				  temp percent_agreement intermediate part1 part2 intermediate_yr_summary_report intermediate_summary_report temp1 ; 
	run;
	quit;

	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0  %then %do;
		%if &distinct_categvar_refdb. le 2 %then %do;
			proc datasets lib=&templib. nolist;
				delete part1 part2 kappa_linktype kappa_yr_linktype kappaCoeff; 
			run;
			quit;
		%end;
	%end;
%mend agreement_stats;
