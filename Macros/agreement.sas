/*========================================================================  
DataFit Toolkit - Agreement macro
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
  |				 (date of birth and sex). The results will be an html page with tables and plots
  |
  | PARAMETERS:  
  |
  | EXAMPLES:    
  |
  | UPDATES:    2017-05-01 (Gangamma Kalappa)
  |              - Converted the program written by Behtash to a macro  
  | 			2017-06-06 (Gangamma Kalappa)
  |              - Fixed the bug flagged where temporary dataset was trying to over write library dataset. Found that had missed coding an else 
  |                block. 
*********************************************************************************************************************************************
*********************************************************************************************************************************************/
/*Macro to check parameter values */
%macro agreementCheckParam(lib=,
							 templib=,
							 ds=,
							 ds_prefix=,
							 ds_crosswalk=,
							 ds_mergeby=,
							 ds_linktype=,
							 ds_startyr=,
							 ds_endyr=,
							 ds_byvar=,
							 ds_bydate=,
							 ds_datevar=,
							 ds_categvar=,
							 ref_data=,
							 ref_byvar=,
							 ref_datevar=,
							 ref_categvar=,
							 time=fiscal,
							 path=
							);
	/*Defining local variables*/
	%local dsid rc dsid1 rc1 year dbnames_list counter counter2 temporarylib tempds;

	/*Check if ds_datevar and ds_categvar both have null value. In which case macro will not execute */
	%if (%sysevalf(%superq(ds_datevar)=,boolean) eq 1 and %sysevalf(%superq(ds_categvar)=,boolean) eq 1) %then %do;
		%put;
		%put ERROR: Parameters ds_datevar and ds_categvar have null value;
		%put NOTE: For the execution of macro atleast one of variable ds_datevar or ds_categvar should have valid value;
		%put NOTE: Macro will be terminated;
		%put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end;

	/*Check if lib parameter has been specified and if it exists*/
	%if %sysevalf(%superq(lib)=,boolean) eq 1 %then %do;
		%put;
		%put ERROR: Library name has not been specified;
	    %put NOTE:  Please specify a valid library name;
	    %put NOTE:  Macro will be terminated;
	    %put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end;
	%else %do;
		%if (%sysfunc(libref(&lib.))) %then %do;
			%put;
			%put ERROR: Library name &lib. specified has not been assigned;
		    %put NOTE:  Please specify a valid assigned library name;
		    %put NOTE:  Macro will be terminated;
		    %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
	%end;

	/*Check if temporary library specified exists*/
	%if (%sysfunc(libref(&templib.))) %then %do;
			%put;
			%put ERROR: Library name &templib. specified has not been assigned;
		    %put NOTE:  Please specify a valid assigned temporary library name;
		    %put NOTE:  Macro will be terminated;
		    %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
	%end;

	/*Check if the value specified for ds_prefix parameter is valid or not*/
    %if (&ds_prefix. ne OFF and &ds_prefix. ne ON ) %then %do;
        %put ERROR: Incorrect value specified for parameter ds_prefix;
        %put NOTE: You can only specify one of the following values for the ds_prefix parameter: ON, OFF;
        %put NOTE: Macro will be terminated;
        %put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end;

	/*Check if the input dataset exists*/
	%if %sysevalf(%superq(ds)=,boolean) eq 1 %then %do;
		%put;
		%put ERROR: Input dataset has not been specified;
	    %put NOTE:  Please specify a input dataset;
	    %put NOTE:  Macro will be terminated;
	    %put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end;
	%else %do;
		%if (&ds_prefix. eq OFF and %upcase(&ds.)  ne ALL) %then %do;
			%if %sysfunc(exist(&lib..&ds.)) eq 0 %then %do;
				%put;
			    %put ERROR: Input dataset specified &ds. does not exists in &lib. library ;
			    %put NOTE: Please specify a valid input dataset name;
			    %put NOTE: Macro will be terminated;
			    %put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;
	%end;

	/*Check if the input crosswalk dataset exists*/
	%if (%sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 and %upcase(&ds.)  ne ALL)%then %do;
		%let temporarylib=%scan(&ds_crosswalk.,1,".");
		%let tempds=%scan(&ds_crosswalk.,2,".");
		%if %sysfunc(exist(&temporarylib..&tempds.)) eq 0 %then %do;
			%put;
			%put ERROR: Input crosswalk dataset specified &temporarylib..&tempds. does not exists;
			%put NOTE: Please specify a valid crosswalk dataset name;
			%put NOTE: Macro will be terminated;
			%put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;

	%end;

	/*For non-cummulative datasets date parameters are mandatory*/
	/*Check if ds_startyr and ds_endyr are parameters are passed when ds_prefix option is ON*/
	%if (&ds_prefix. eq ON) %then %do;
		%if %sysevalf(%superq(ds_startyr)=,boolean) eq 1 %then %do;
	        %put;
	        %put ERROR: Parameter ds_startyr has null value;
	        %put NOTE: Please specify a valid 4 digit year as value for ds_startyr parameter;
	        %put NOTE: Macro will be terminated;
	        %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
		%if %sysevalf(%superq(ds_endyr)=,boolean) eq 1 %then %do;
	        %put;
	        %put ERROR: Parameter ds_endyr has null value;
	        %put NOTE: Please specify a valid 4 digit year as value for ds_endyr parameter;
	        %put NOTE: Macro will be terminated;
	        %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;

		%if %sysevalf(%superq(ds_bydate)=,boolean) eq 1 %then %do;
	        %put;
	        %put ERROR: Parameter ds_bydate has null value;
	        %put NOTE: Please specify a valid date variable  as value for ds_bydate parameter;
	        %put NOTE: Macro will be terminated;
	        %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;

		%do year=&ds_startyr. %to &ds_endyr.;
			%if %sysfunc(exist(%upcase(&lib.).%upcase(&ds.)&year.)) = 1 %then %do;
				%if %length(&dbnames_list.) eq 0 %then %let dbnames_list="%upcase(&ds.)&year.";
				%else %let dbnames_list=&dbnames_list. , "%upcase(&ds.)&year.";
			%end;
		%end;
		%if %length(&dbnames_list.) eq 0 %then %do;
			%put;
			%put ERROR: No datasets were found in %upcase(&lib.) library with prefix of %upcase(&ds.) followed by suffix &ds_startyr. through &ds_endyr.;
			%put NOTE: Please provide valid prefix and suffix information;
			%put NOTE: Macro will be terminated;
			%put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
	%end;

	/*Check scenarios related to ds_crosswalk and ds_mergeby parameter*/
	/*Check if ds_mergeby has been specified when ds_crosswalk is not null*/
	%if (%sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 and %sysevalf(%superq(ds_mergeby)=,boolean) eq 1 and %upcase(&ds.)  ne ALL) %then %do;
		%put;
		%put ERROR: Parameter ds_mergeby has null value;
		%put NOTE: Please specify a valid variable name in parameter ds_mergeby;
		%put NOTE: Macro will be terminated;
		%put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end;
	%else %if (%sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 and %sysevalf(%superq(ds_mergeby)=,boolean) eq 0 and %upcase(&ds.)  ne ALL) %then %do;
		/*Check if the variable name specified as value for parameter ds_mergeby exists crossswalk dataset*/
		%let dsid=%sysfunc(open(&ds_crosswalk.));	
		%if %sysfunc(varnum(&dsid., &ds_mergeby.)) eq 0 %then %do;
			%let rc=%sysfunc(close(&dsid));
			%put;
			%put ERROR: Variable &ds_mergeby specified as value for parameter ds_mergeby does not exist in &ds_crosswalk. crosswalk dataset ;
			%put NOTE: Macro will be terminated;
			%put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
		%let rc=%sysfunc(close(&dsid));

		/*Check if the variable name specified as value for parameter ds_mergeby exists input dataset*/
		/*if ds_prefix parameter equal to ON (annual dataset then check for the existence of ds_mergeby all of  annual datasets for the specied
		startyr and endyr range; else if ds_prefix=OFF then check for the existence of ds_mergeby in input dataset*/
		%if &ds_prefix. eq ON %then %do;
			%let counter=0;
			proc sql noprint;
				select count(name) into : counter from dictionary.columns 
						where libname="%upcase(&lib.)" and memname in (&dbnames_list.) and upcase(name) eq "%upcase(&ds_mergeby.)"
						group by name; 
			quit;
			%if (&counter. eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_mergeby specified as value for parameter ds_mergeby does not exist in input datasets;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;
		%else %do;
			%let dsid=%sysfunc(open(&lib..&ds.));
			%if %sysfunc(varnum(&dsid, &ds_mergeby.))eq 0 %then %do;
				%let rc=%sysfunc(close(&dsid));
				%put;
				%put ERROR: Variable &ds_mergeby specified as value for parameter ds_mergeby does not exist in input dataset &lib..&ds.;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;
		%let rc=%sysfunc(close(&dsid));
	%end;
	%else %if (%sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 and %sysevalf(%superq(ds_mergeby)=,boolean) eq 0 and &ds_prefix. eq ON and %upcase(&ds.)  eq ALL) %then %do;
		%let counter=0;
		proc sql noprint;
			select count(name) into : counter from dictionary.columns 
					where libname="%upcase(&lib.)" and memname in (&dbnames_list.) and upcase(name) eq "%upcase(&ds_mergeby.)"
					group by name; 
		quit;
		%if (&counter. eq 0) %then %do;
			%put;
			%put ERROR: Variable &ds_mergeby specified as value for parameter ds_mergeby does not exist in input datasets;
			%put NOTE: Macro will be terminated;
			%put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
	%end;

	/*Check for ds_linktype, ds_byvar, ds_bydate, ds_datevar and ds_categvar  parameter value*/
	/*Check when ds_prefix is OFF and ds is not ALL*/
	%if  (&ds_prefix. eq OFF and %upcase(&ds.) ne ALL)%then %do;
		%let dsid=%sysfunc(open(&lib..&ds.));
		/*Check for ds_linktype parameter value*/
		%if %sysevalf(%superq(ds_linktype)=,boolean) eq 0 %then %do;
			%if %sysfunc(varnum(&dsid, &ds_linktype.))eq 0 %then %do;
				%let rc=%sysfunc(close(&dsid));
				%put;
			    %put ERROR: Variable &ds_linktype specified as value for parameter ds_linktype does not exist in input dataset &lib..&ds.;
			    %put NOTE: Macro will be terminated;
			    %put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
			%else %do;
				%let agreement_linktype_db=DS;
			%end;
		%end;
		
		/*Check if specified ds_bydate exists in the datasets*/
		%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 %then %do;
			%if (%sysevalf(%superq(ds_crosswalk)=,boolean) eq 1) %then %do;
				%if %sysfunc(varnum(&dsid, &ds_bydate.))eq 0 %then %do;
					%let rc=%sysfunc(close(&dsid));
					%put;
				    %put ERROR: Variable &ds_bydate specified as value for parameter ds_bydate does not exist in input dataset &lib..&ds.;
				    %put NOTE: Macro will be terminated;
				    %put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %do;
					%let agreement_bydate_db=DS;
				%end;
			%end;
			%else %do;
				%let dsid1=%sysfunc(open(&temporarylib..&tempds.));
				%if (%sysfunc(varnum(&dsid1, &ds_bydate.))eq 0 and %sysfunc(varnum(&dsid, &ds_bydate.))eq 0) %then %do;
					%let rc=%sysfunc(close(&dsid));
					%let rc1=%sysfunc(close(&dsid1));
					%put;
				    %put ERROR: Variable &ds_bydate specified as value for parameter ds_bydate neither exist in input dataset nor in crosswalk dataset;
				    %put NOTE: Macro will be terminated;
				    %put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %if (%sysfunc(varnum(&dsid1, &ds_bydate.)) ne 0) %then %do;
					%let agreement_bydate_db=CROSSWALK;
				%end;
				%else %if (%sysfunc(varnum(&dsid, &ds_bydate.))ne 0) %then %do;
					%let agreement_bydate_db=DS;
				%end;
				%let rc1=%sysfunc(close(&dsid1));
			%end;
		%end;

		/*Check if specified ds_byvar exists in the datasets*/
		%if %sysevalf(%superq(ds_byvar)=,boolean) eq 0 %then %do;
			%if %sysfunc(varnum(&dsid, &ds_byvar.))eq 0 %then %do;
				%let rc=%sysfunc(close(&dsid));
				%put;
			    %put ERROR: Variable &ds_byvar specified as value for parameter ds_byvar does not exist in input dataset &lib..&ds.;
			    %put NOTE: Macro will be terminated;
			    %put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
			%else %do;
				%let agreement_byvar_db=DS;
			%end;
		%end;
		%let rc=%sysfunc(close(&dsid));

		/*Check if specified ds_datevar exists in the datasets*/
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			%let counter=0;
			%let counter2=0;
			proc sql noprint;
					select count(name) into : counter from dictionary.columns 
							where libname="%upcase(&lib.)" and memname="%upcase(&ds.)" and upcase(name) eq "%upcase(&ds_datevar.)"
							group by name; 
			quit;
			/*If crosswalk is specified*/
			%if %sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 %then %do;
				proc sql noprint;		
						select count(name) into : counter2 from dictionary.columns 
							where libname="%upcase(&temporarylib.)" and memname="%upcase(&tempds.)" and upcase(name) eq "%upcase(&ds_datevar.)"
							group by name; 
				quit;
				%if (&counter. eq 0 and &counter2. eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_datevar specified as value for parameter ds_datevar neither exists in input dataset nor in crosswalk dataset;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %if (&counter2. ne 0) %then %do;
					%let agreement_datevar_db=CROSSWALK;
				%end;
				%else %if (&counter. ne 0) %then %do;
					%let agreement_datevar_db=DS;
				%end;
			%end;
			%else %do;
				%if (&counter. eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_datevar specified as value for parameter ds_datevar does not exist in input dataset &lib..&ds.;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %do;
					%let agreement_datevar_db=DS;
				%end;
			%end;
		%end;

		/*Check if specified ds_categvar exists in the datasets*/
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
			%let counter2=0;
			%let counter=0;
			proc sql noprint;
					select count(name) into : counter from dictionary.columns 
							where libname="%upcase(&lib.)" and memname="%upcase(&ds.)" and upcase(name) eq "%upcase(&ds_categvar.)"
							group by name; 
			quit;
			/*If crosswalk is specified*/
			%if %sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 %then %do;
				proc sql noprint;		
						select count(name) into : counter2 from dictionary.columns 
							where libname="%upcase(&temporarylib.)" and memname="%upcase(&tempds.)" and upcase(name) eq "%upcase(&ds_categvar.)"
							group by name; 
				quit;

				%if (&counter. eq 0 and &counter2. eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_categvar specified as value for parameter ds_categvar neither exists in input dataset nor in crosswalk dataset;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %if (&counter2. ne 0) %then %do;
					%let agreement_categvar_db=CROSSWALK;
				%end;
				%else %if (&counter. ne 0) %then %do;
					%let agreement_categvar_db=DS;
				%end;
			%end;
			%else %do;
				%if (&counter. eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_categvar specified as value for parameter ds_categvar does not exist in input dataset &lib..&ds.;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %do;
					%let agreement_categvar_db=DS;
				%end;
			%end;
		%end;
	%end;
	/*----------------------------------------------------------------------------------------------------------------------------*/
	/*Check when ds_prefix is ON*/
	%else %if (&ds_prefix. eq ON ) %then %do;
		/*Check for ds_linktype parameter value*/
		%if %sysevalf(%superq(ds_linktype)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
					select count(name) into : counter from dictionary.columns 
							where libname="%upcase(&lib.)" and memname in (&dbnames_list.) and upcase(name) eq "%upcase(&ds_linktype.)"
							group by name; 
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_linktype specified as value for parameter ds_linktype does not exist in input datasets;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
			%else %do;
				%let agreement_linktype_db=DS;
			%end;
		%end;

		/*Check if specified ds_bydate exists in the datasets*/
		%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
					select count(name) into : counter from dictionary.columns 
							where libname="%upcase(&lib.)" and memname in (&dbnames_list.) and upcase(name) eq "%upcase(&ds_bydate.)"
							group by name; 
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_bydate specified as value for parameter ds_bydate does not exist in input datasets;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
			%else %do;
				%let agreement_bydate_db=DS;
			%end;
		%end;

		/*Check if specified ds_byvar exists in the datasets*/
		%if %sysevalf(%superq(ds_byvar)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
					select count(name) into : counter from dictionary.columns 
							where libname="%upcase(&lib.)" and memname in (&dbnames_list.) and upcase(name) eq "%upcase(&ds_byvar.)"
							group by name; 
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_byvar specified as value for parameter ds_byvar does not exist in input datasets;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
			%else %do;
				%let agreement_byvar_db=DS;
			%end;
		%end;

		/*Check if specified ds_datevar exists in the datasets*/
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			%let counter=0;
			%let counter2=0;
			proc sql noprint;
				select count(name) into : counter from dictionary.columns 
							where libname="%upcase(&lib.)" and memname in (&dbnames_list.) and upcase(name) eq "%upcase(&ds_datevar.)"
							group by name; 
			quit;
			/*If crosswalk is specified*/
			%if %sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 %then %do;
				proc sql noprint;		
						select count(name) into : counter2 from dictionary.columns 
							where libname="%upcase(&temporarylib.)" and memname="%upcase(&tempds.)" and upcase(name) eq "%upcase(&ds_datevar.)"
								group by name; 
				quit;
				%if (&counter eq 0 and &counter2 eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_datevar specified as value for parameter ds_datevar neither exists in input datasets nor in crosswalk dataset;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %if (&counter2. ne 0) %then %do;
					%let agreement_datevar_db=CROSSWALK;
				%end;
				%else %if (&counter. ne 0) %then %do;
					%let agreement_datevar_db=DS;
				%end;
			%end;
			%else %do;
				%if (&counter eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_datevar specified as value for parameter ds_datevar does not exist in input datasets;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %do;
					%let agreement_datevar_db=DS;
				%end;
			%end;
		%end;

		/*Check if specified ds_categvar exists in the datasets*/
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
			%let counter=0;
			%let counter2=0;
			proc sql noprint;
				select count(name) into : counter from dictionary.columns 
							where libname="%upcase(&lib.)" and memname in (&dbnames_list.) and upcase(name) eq "%upcase(&ds_categvar.)"
							group by name; 
			quit;
			/*If crosswalk is specified*/
			%if %sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 %then %do;
				proc sql noprint;		
						select count(name) into : counter2 from dictionary.columns 
							where libname="%upcase(&temporarylib.)" and memname="%upcase(&tempds.)" and upcase(name) eq "%upcase(&ds_categvar.)"
								group by name; 
				quit;
				%if (&counter eq 0 and &counter2 eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_categvar specified as value for parameter ds_categvar neither exists in input datasets nor in crosswalk dataset;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %if (&counter2. ne 0) %then %do;
					%let agreement_categvar_db=CROSSWALK;
				%end;
				%else %if (&counter. ne 0) %then %do;
					%let agreement_categvar_db=DS;
				%end;
			%end;
			%else %do;
				%if (&counter. eq 0) %then %do;
					%put;
					%put ERROR: Variable &ds_categvar specified as value for parameter ds_categvar does not exist in input datasets;
					%put NOTE: Macro will be terminated;
					%put;
					%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
					%abort;
				%end;
				%else %do;
					%let agreement_categvar_db=DS;
				%end;
			%end;
		%end;
	%end;
	/*----------------------------------------------------------------------------------------------------------------------------*/
	/*Check when ds_prefix is OFF and ds is ALL*/
	%else %if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds.) eq ALL) %then %do;
		/*Check for ds_linktype parameter value*/
		%if %sysevalf(%superq(ds_linktype)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
				select count(name) into :counter 
							from dictionary.columns 
							where libname="%upcase(&lib.)" and upcase(name) eq "%upcase(&ds_linktype.)"
							group by name;  
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_linktype specified as value for parameter ds_linktype does not exist any of the datasets in %upcase(&lib.) library;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;

		/*Check if specified ds_bydate exists in the datasets*/
		%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
				select count(name) into :counter 
							from dictionary.columns 
							where libname="%upcase(&lib.)" and upcase(name) eq "%upcase(&ds_bydate.)"
							group by name;  
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_bydate specified as value for parameter ds_bydate does not exist any of the datasets in %upcase(&lib.) library;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;

		/*Check if specified ds_byvar exists in the datasets*/
		%if %sysevalf(%superq(ds_byvar)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
				select count(name) into :counter 
							from dictionary.columns 
							where libname="%upcase(&lib.)" and upcase(name) eq "%upcase(&ds_byvar.)"
							group by name;  
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_byvar specified as value for parameter ds_byvar does not exist any of the datasets in %upcase(&lib.) library;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;

		/*Check if specified ds_datevar exists in the datasets*/
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
				select count(name) into :counter 
							from dictionary.columns 
							where libname="%upcase(&lib.)" and upcase(name) eq "%upcase(&ds_datevar.)"
							group by name; 
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_datevar specified as value for parameter ds_datevar does not exist any of the datasets in %upcase(&lib.) library;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;

		/*Check if specified ds_categvar exists in the datasets*/
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
			%let counter=0;
			proc sql noprint;
			select count(name) into :counter 
						from dictionary.columns 
						where libname="%upcase(&lib.)" and upcase(name) eq "%upcase(&ds_categvar.)"
						group by name; 
			quit;
			%if (&counter eq 0) %then %do;
				%put;
				%put ERROR: Variable &ds_categvar specified as value for parameter ds_categvar does not exist any of the datasets in %upcase(&lib.) library;
				%put NOTE: Macro will be terminated;
				%put;
				%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
				%abort;
			%end;
		%end;
	%end;

	/*Check if reference dataset exists*/
	%if %sysfunc(exist(&ref_data.)) eq 0 %then %do;
		%put;
		%put ERROR: Reference dataset specified &ref_data. does not exists;
		%put NOTE: Please specify a valid reference dataset name (<libname>.<datasetname>);
		%put NOTE: Macro will be terminated;
		%put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end; 

	/*Check if varaibles mentioned as parameter value for reference dataset exists in reference dataset*/
	%let dsid=%sysfunc(open(&ref_data));
	%if %sysfunc(varnum(&dsid, &ref_byvar))eq 0 %then %do;
		%let rc=%sysfunc(close(&dsid));
		%put;
	    %put ERROR: Variable &ref_byvar specified as value for parameter ref_byvar does not exist in reference dataset &ref_data.;
	    %put NOTE: Macro will be terminated;
	    %put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end;
	%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
		%if %sysfunc(varnum(&dsid, &ref_datevar))eq 0 %then %do;
			%let rc=%sysfunc(close(&dsid));
			%put;
		    %put ERROR: Variable &ref_datevar specified as value for parameter ref_datevar does not exist in reference dataset &ref_data.;
		    %put NOTE: Macro will be terminated;
		    %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
	%end;
	%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
		%if %sysfunc(varnum(&dsid, &ref_categvar))eq 0 %then %do;
			%let rc=%sysfunc(close(&dsid));
			%put;
		    %put ERROR: Variable &ref_categvar specified as value for parameter ref_categvar does not exist in reference dataset &ref_data.;
		    %put NOTE: Macro will be terminated;
		    %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
	%end;
	%let rc=%sysfunc(close(&dsid));
	/*Check if the value specified for TIME parameter is valid or not*/
    %if &time^=FISCAL %then %if &time^=CALENDAR %then %do;
        %put;
        %put ERROR: Wrong value for TIME: &TIME;
        %put NOTE: You can only specify one of the following values for the TIME parameter: FISCAL, CALENDAR;
        %put NOTE: Macro will be terminated;
        %put;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end;

	/*Check if output path specified by user exists*/
	%if %sysevalf(%superq(path)=,boolean) eq 0 %then %do;
		%if %sysfunc(fileexist(&path.)) = 0 %then %do;
	        %put;
	        %put ERROR:&PATH. does not exist;
			%put NOTE: Please specify a valid directory path;
	        %put NOTE: Macro will be terminated;
	        %put;
			%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
			%abort;
		%end;
	%end;
	%else %do;
		%put;
	    %put ERROR: PATH parameter contains null value;
	    %put NOTE: Please specify a valid directory path;
	    %put NOTE: Macro will be terminated;
	    %put ;
		%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;
		%abort;
	%end; 
%mend agreementCheckParam;


/*******************************************************************************************************************************************/
/*Macro to create yr variable based on different scenarios */
%macro agreementDateRange (templib=,
						   ds_new=,
						   ds_startyr=,
						   ds_endyr=,
						   ds_bydate=,
						   time=);

	%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 %then %do;
		%local bydatefmtindata;
	    proc sql noprint;
	    	select format into: bydatefmtindata from dictionary.columns
	       						where upcase(libname) = "%upcase(&templib.)" and
	         						  upcase(memname) = "%upcase(&ds_new.)" and
	         						  upcase(name)    = "%upcase(&ds_bydate.)";
	    quit; 

		%if (%sysevalf(%superq(ds_startyr)=,boolean) eq 0) and (%sysevalf(%superq(ds_endyr)=,boolean) eq 0) %then %do;
			%if %upcase(&time.)=FISCAL %then %do;
		    	%fiscalyr(&ds_startyr.,&ds_endyr.) ;;
		    %end;
			%else %if %upcase(&time.)=CALENDAR %then %do;
		        %calendaryr(&ds_startyr.,&ds_endyr.);;
		    %end;

			data &templib..&ds_new.;
				set &templib..&ds_new.;
				length yr  $ 11 ;
		        %if %sysfunc(compress(&bydatefmtindata, ., d)) = DATETIME %then %do;
		        	&bydate = datepart(&ds_bydate);
		          	format &ds_bydate date9.;
		        %end;
			    %if &time=FISCAL %then yr=put(&ds_bydate,fy.);;
        	    %if &time=CALENDAR %then yr=put(&ds_bydate,cy.);;
			run;
		%end;
		%else %do;
			data &templib..&ds_new.;
				set &templib..&ds_new.;
				length yr  $ 11 ;
		       %if %sysfunc(compress(&bydatefmtindata, ., d)) = DATETIME %then %do;
		          &bydate = datepart(&ds_bydate);
		          format &ds_bydate date9.;
		       %end;
			   if not missing(&ds_bydate.) then do;
				   /*'year.4' starts from April. If we say 'Year.10' then FISCAl year would begin from October*/
					%if %upcase(&time.) eq FISCAL %then %do;
						yr=put(intnx('year.4',&ds_bydate.,0,'B'),year4.)||"/"||put(intnx('year.4',&ds_bydate.,0,'E'),year2.);
					%end;
					%else %if %upcase(&time.) eq CALENDAR %then %do;
						yr=put(intnx('year.1',&ds_bydate.,0,'B'),year4.);
					%end;
				end;
			run;
		%end;
	%end;
%mend agreementDateRange;


/*******************************************************************************************************************************************/
/*Macro to clean and create the final dataset */
%macro agreementCleanData ( templib=,
							ds_new=,
							ds_linktype=,
							ds_byvar=,
							ds_datevar=,
							ds_categvar=, 
						 	ref_byvar=,
				 		 	ref_datevar=,
				 		 	ref_categvar=);

	%local inds datevarfmtindata;
	%let inds = %lowcase(&ds_new.);

	%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
		proc sql noprint;
		    select format into: datevarfmtindata from dictionary.columns
		       						where upcase(libname) = "%upcase(&templib.)" and
		         						  upcase(memname) = "%upcase(&ds_new.)" and
		         						  upcase(name)    = "%upcase(&ds_datevar.)";
		quit; 
	%end;

    data &templib..&ds_new.;
       	set &templib..&ds_new.;
		%if %sysevalf(%superq(ds_linktype)=,boolean) eq 1 %then %do;
	   		length link_type $1;
			link_type="D";
		%end;

		%if (%sysevalf(%superq(ds_datevar)=,boolean) eq 0) and (%sysfunc(compress(&datevarfmtindata, ., d)) = DATETIME) %then %do;
			&ds_datevar = datepart(&ds_datevar);
			format &ds_datevar date9.;
		%end;
		where &ds_byvar. is not missing;
    run;

	data &templib..&ds_new.;
       	set &templib..&ds_new.;
		%if %sysfunc(strip(&ds_byvar.)) ne %sysfunc(strip(&ref_byvar.)) %then %do;
			rename &ds_byvar.=&ref_byvar.;
		%end;

		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			rename &ds_datevar.= &inds._&ds_datevar.;
		%end;

		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
			rename	&ds_categvar.=&inds._&ds_categvar.;	 
		%end;
	run;

	/*Delete duplicate rows*/
	proc sort data=&templib..&ds_new. out=&templib..temp nodupkey;
		by _all_;
	run;

	proc sort data=&templib..temp out=&templib..&ds_new.;
		by &ref_byvar.;
	run;
%mend agreementCleanData;


/*******************************************************************************************************************************************/
/*Macro to create dataset for agreement stats based on information provided by users*/
%macro agreementCreateDb (lib=,
						 templib=,
						 ds=,
						 ds_prefix=,
						 ds_crosswalk=,
						 ds_mergeby=,
						 ds_linktype=,
						 ds_startyr=,
						 ds_endyr=,
						 ds_byvar=,
						 ds_bydate=,
						 ds_datevar=,
						 ds_categvar=,
						 time =,
						 ref_byvar=,
				 		 ref_datevar=,
				 		 ref_categvar=);
	%local dbnames_lst doi dbname;

	/*When ds_prefix is OFF and ds is not ALL*/
	%if (&ds_prefix. eq OFF and %upcase(&ds.)  ne ALL) %then %do;
		%if %sysevalf(%superq(ds_crosswalk)=,boolean) eq 1 %then %do;
			data &templib..&ds.;
				set &lib..&ds. (keep=
						%if %sysevalf(%superq(ds_linktype)=,boolean) eq 0 %then %do;
							&ds_linktype.
						%end;
						%if %sysevalf(%superq(ds_byvar)=,boolean) eq 0 %then %do;
							&ds_byvar.
						%end; 
						%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 and %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
							%if &ds_bydate. eq &ds_datevar. %then %do;
								&ds_bydate.
							%end;
							%else %do;
								&ds_bydate.
								&ds_datevar.
							%end;
						%end; 
						%else %if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 %then %do;
							&ds_bydate.
						%end;
						%else %if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
							&ds_datevar.
						%end;
						%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
							&ds_categvar.
						%end;
					);
			run;

			%agreementDateRange (templib=&templib.,
								 ds_new=&ds.,
								 ds_startyr=&ds_startyr.,
						   		 ds_endyr=&ds_endyr.,
						   		 ds_bydate=&ds_bydate.,
								 time = &time.)

			%agreementCleanData ( templib=&templib.,
								  ds_new=&ds.,
									ds_linktype=&ds_linktype.,
									ds_byvar=&ds_byvar.,
									ds_datevar=&ds_datevar.,
									ds_categvar=&ds_categvar., 
								 	ref_byvar=&ref_byvar.,
						 		 	ref_datevar=&ref_datevar.,
						 		 	ref_categvar=&ref_categvar.);				 
		%end;
		%else %do;
			/*Retrieving variables input dataset*/
			data &templib..&lib._intermediate;
				set &lib..&ds. (keep=
						%if (%sysevalf(%superq(ds_mergeby)=,boolean) eq 0) %then %do;
							&ds_mergeby.
						%end;
						%if (%sysevalf(%superq(ds_linktype)=,boolean) eq 0 and &agreement_linktype_db. eq DS) %then %do;
							&ds_linktype.
						%end;
						%if (%sysevalf(%superq(ds_byvar)=,boolean) eq 0 and &agreement_byvar_db. eq DS) %then %do;
							&ds_byvar.
						%end; 
						%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 and %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
							%if &ds_bydate. eq &ds_datevar. %then %do;
								%if &agreement_bydate_db. eq DS %then %do;
										&ds_bydate.
								%end;
							%end;
							%else %do;
								%if &agreement_bydate_db. eq DS %then %do;
										&ds_bydate.
								%end;
								%if &agreement_datevar_db. eq DS %then %do;
										&ds_datevar.
								%end;
							%end;
						%end; 
						%else %if (%sysevalf(%superq(ds_bydate)=,boolean) eq 0 and &agreement_bydate_db. eq DS) %then %do;
							&ds_bydate.
						%end;
						%else %if (%sysevalf(%superq(ds_datevar)=,boolean) eq 0 and &agreement_datevar_db. eq DS) %then %do;
							&ds_datevar.
						%end;
						%if (%sysevalf(%superq(ds_categvar)=,boolean) eq 0 and &agreement_categvar_db. eq DS) %then %do;
							&ds_categvar.
						%end;
					);
			run;

			proc sort data= &templib..&lib._intermediate;
				by 	&ds_mergeby.;
			run;

			/*Retrieving variables crosswalk dataset*/
			data &templib..&lib._crosswalk;
				set &ds_crosswalk. (keep=
										%if (%sysevalf(%superq(ds_mergeby)=,boolean) eq 0) %then %do;
											&ds_mergeby.
										%end;
										%if (%sysevalf(%superq(ds_linktype)=,boolean) eq 0 and &agreement_linktype_db. eq CROSSWALK) %then %do;
											&ds_linktype.
										%end;
										%if (%sysevalf(%superq(ds_byvar)=,boolean) eq 0 and &agreement_byvar_db. eq CROSSWALK) %then %do;
											&ds_byvar.
										%end; 
										%if (%sysevalf(%superq(ds_bydate)=,boolean) eq 0 and %sysevalf(%superq(ds_datevar)=,boolean) eq 0) %then %do;
											%if &ds_bydate. eq &ds_datevar. %then %do;
												%if &agreement_bydate_db. eq CROSSWALK %then %do;
													&ds_bydate.
												%end;
											%end;
											%else %do;
												%if &agreement_bydate_db. eq CROSSWALK %then %do;
													&ds_bydate.
												%end;
												%if &agreement_datevar_db. eq CROSSWALK %then %do;
													&ds_datevar.
												%end;	
											%end;
										%end; 
										%else %if (%sysevalf(%superq(ds_bydate)=,boolean) eq 0 and &agreement_bydate_db. eq CROSSWALK)  %then %do;
											&ds_bydate.
										%end;
										%else %if (%sysevalf(%superq(ds_datevar)=,boolean) eq 0 and &agreement_datevar_db. eq CROSSWALK) %then %do;
											&ds_datevar.
										%end;
										%if (%sysevalf(%superq(ds_categvar)=,boolean) eq 0 and &agreement_categvar_db. eq CROSSWALK) %then %do;
											&ds_categvar.
										%end;
									);

			run;

			proc sort data= &templib..&lib._crosswalk;
				by 	&ds_mergeby.;
			run;

			/*Merging variables retrieved from input dataset and crosswalk datasets*/
			data &templib..&ds.;
				merge &templib..&lib._intermediate (in=a) &templib..&lib._crosswalk (in=b);
				by 	&ds_mergeby.;
				if a and b then output;
			run;

			proc datasets lib=&templib. nolist;
				delete &lib._intermediate &lib._crosswalk;
			run;
			quit;

			%agreementDateRange (templib=&templib.,
								 ds_new=&ds.,
								 ds_startyr=&ds_startyr.,
						   		 ds_endyr=&ds_endyr.,
						   		 ds_bydate=&ds_bydate.,
								 time = &time.)

			%agreementCleanData ( templib=&templib.,
								 	ds_new=&ds.,
									ds_linktype=&ds_linktype.,
									ds_byvar=&ds_byvar.,
									ds_datevar=&ds_datevar.,
									ds_categvar=&ds_categvar., 
								 	ref_byvar=&ref_byvar.,
						 		 	ref_datevar=&ref_datevar.,
						 		 	ref_categvar=&ref_categvar.);
		%end;
	%end;

	/*----------------------------------------------------------------------------------------------------------------------------*/
	/*When ds_prefix is ON*/
	%else %if (&ds_prefix. eq ON ) %then %do;
		%if %sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 %then %do;
			/*Retrieving variables input dataset*/
			data &templib..&lib._intermediate;
		        set 
				%do year=&ds_startyr. %to &ds_endyr.;
					%if %sysfunc(exist(&lib..&ds.&year.)) = 1 %then %do;
							&lib..&ds.&year. (keep=
											%if (%sysevalf(%superq(ds_mergeby)=,boolean) eq 0) %then %do;
												&ds_mergeby.
											%end;
											%if (%sysevalf(%superq(ds_linktype)=,boolean) eq 0 and &agreement_linktype_db. eq DS) %then %do;
												&ds_linktype.
											%end;
											%if (%sysevalf(%superq(ds_byvar)=,boolean) eq 0 and &agreement_byvar_db. eq DS) %then %do;
												&ds_byvar.
											%end; 
											%if (%sysevalf(%superq(ds_bydate)=,boolean) eq 0 and %sysevalf(%superq(ds_datevar)=,boolean) eq 0) %then %do;
												%if &ds_bydate. eq &ds_datevar. %then %do;
													%if &agreement_bydate_db. eq DS %then %do;
														&ds_bydate.
													%end;
												%end;
												%else %do;
													%if &agreement_bydate_db. eq DS %then %do;
														&ds_bydate.
													%end;
													%if &agreement_datevar_db. eq DS %then %do;
														&ds_datevar.
													%end;	
												%end;
											%end; 
											%else %if (%sysevalf(%superq(ds_bydate)=,boolean) eq 0 and &agreement_bydate_db. eq DS)  %then %do;
												&ds_bydate.
											%end;
											%else %if (%sysevalf(%superq(ds_datevar)=,boolean) eq 0 and &agreement_datevar_db. eq DS) %then %do;
												&ds_datevar.
											%end;
											%if (%sysevalf(%superq(ds_categvar)=,boolean) eq 0 and &agreement_categvar_db. eq DS) %then %do;
												&ds_categvar.
											%end;
										)
					%end;
				%end;
				;
			run;

			proc sort data= &templib..&lib._intermediate;
				by 	&ds_mergeby.;
			run;

			/*Retrieving variables crosswalk dataset*/
			data &templib..&lib._crosswalk;
				set &ds_crosswalk. (keep=
										%if (%sysevalf(%superq(ds_mergeby)=,boolean) eq 0) %then %do;
											&ds_mergeby.
										%end;
										%if (%sysevalf(%superq(ds_linktype)=,boolean) eq 0 and &agreement_linktype_db. eq CROSSWALK) %then %do;
											&ds_linktype.
										%end;
										%if (%sysevalf(%superq(ds_byvar)=,boolean) eq 0 and &agreement_byvar_db. eq CROSSWALK) %then %do;
											&ds_byvar.
										%end; 
										%if (%sysevalf(%superq(ds_bydate)=,boolean) eq 0 and %sysevalf(%superq(ds_datevar)=,boolean) eq 0) %then %do;
											%if &ds_bydate. eq &ds_datevar. %then %do;
												%if &agreement_bydate_db. eq CROSSWALK %then %do;
													&ds_bydate.
												%end;
											%end;
											%else %do;
												%if &agreement_bydate_db. eq CROSSWALK %then %do;
													&ds_bydate.
												%end;
												%if &agreement_datevar_db. eq CROSSWALK %then %do;
													&ds_datevar.
												%end;	
											%end;
										%end; 
										%else %if (%sysevalf(%superq(ds_bydate)=,boolean) eq 0 and &agreement_bydate_db. eq CROSSWALK)  %then %do;
											&ds_bydate.
										%end;
										%else %if (%sysevalf(%superq(ds_datevar)=,boolean) eq 0 and &agreement_datevar_db. eq CROSSWALK) %then %do;
											&ds_datevar.
										%end;
										%if (%sysevalf(%superq(ds_categvar)=,boolean) eq 0 and &agreement_categvar_db. eq CROSSWALK) %then %do;
											&ds_categvar.
										%end;
									);

			run;

			proc sort data= &templib..&lib._crosswalk;
				by 	&ds_mergeby.;
			run;
			/*Merging variables retrieved from input dataset and crosswalk datasets*/
			data &templib..&lib._all;
				merge &templib..&lib._intermediate (in=a) &templib..&lib._crosswalk (in=b);
				by 	&ds_mergeby.;
				if a and b then output;
			run;
			proc datasets lib=&templib. nolist;
				delete &lib._intermediate &lib._crosswalk;
			run;
			quit;

			%agreementDateRange (templib=&templib.,
								 ds_new=&lib._all,
								 ds_startyr=&ds_startyr.,
						   		 ds_endyr=&ds_endyr.,
						   		 ds_bydate=&ds_bydate.,
								 time = &time.)

			%agreementCleanData ( templib=&templib.,
								 	ds_new=&lib._all,
									ds_linktype=&ds_linktype.,
									ds_byvar=&ds_byvar.,
									ds_datevar=&ds_datevar.,
									ds_categvar=&ds_categvar., 
								 	ref_byvar=&ref_byvar.,
						 		 	ref_datevar=&ref_datevar.,
						 		 	ref_categvar=&ref_categvar.);
		%end;
		%else %do;
			data &templib..&lib._all;
		        set 
				%do year=&ds_startyr. %to &ds_endyr.;
					%if %sysfunc(exist(&lib..&ds.&year.)) = 1 %then %do;
							&lib..&ds.&year. (keep=
											%if %sysevalf(%superq(ds_linktype)=,boolean) eq 0 %then %do;
												&ds_linktype.
											%end;
											%if %sysevalf(%superq(ds_byvar)=,boolean) eq 0 %then %do;
												&ds_byvar.
											%end; 
											%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 and %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
												%if &ds_bydate. eq &ds_datevar. %then %do;
													&ds_bydate.
												%end;
												%else %do;
													&ds_bydate.
													&ds_datevar.
												%end;
											%end; 
											%else %if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 %then %do;
												&ds_bydate.
											%end;
											%else %if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
												&ds_datevar.
											%end;
											%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
												&ds_categvar.
											%end;
										)
					%end;
				%end;
				;
			run;

			%agreementDateRange (templib=&templib.,
								 ds_new=&lib._all,
								 ds_startyr=&ds_startyr.,
						   		 ds_endyr=&ds_endyr.,
						   		 ds_bydate=&ds_bydate.,
								 time = &time.)

			%agreementCleanData ( templib=&templib.,
								 	ds_new=&lib._all,
									ds_linktype=&ds_linktype.,
									ds_byvar=&ds_byvar.,
									ds_datevar=&ds_datevar.,
									ds_categvar=&ds_categvar., 
								 	ref_byvar=&ref_byvar.,
						 		 	ref_datevar=&ref_datevar.,
						 		 	ref_categvar=&ref_categvar.);
		%end;
	%end;

	/*----------------------------------------------------------------------------------------------------------------------------*/
	/*When ds_prefix is OFF and ds is ALL*/
	%else %if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds.) eq ALL) %then %do;
		proc sql noprint;
			select distinct memname into : dbnames_lst separated by " " from dictionary.columns where libname="%upcase(&lib.)" ; 
		quit;
		%let doi=%eval(%sysfunc(countc(&dbnames_lst.,' '))+1);

		data &templib..&lib._all;
			length dbname $32.;
			set 
			%do i=1 %to &doi.;
				%let dbname=%scan(&dbnames_lst.,&i.);
				&lib..&dbname. (keep=
									%if %sysevalf(%superq(ds_linktype)=,boolean) eq 0 %then %do;
										&ds_linktype.
									%end;
									%if %sysevalf(%superq(ds_byvar)=,boolean) eq 0 %then %do;
										&ds_byvar.
									%end; 
									%if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 and %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
										%if &ds_bydate. eq &ds_datevar. %then %do;
											&ds_bydate.
										%end;
										%else %do;
											&ds_bydate.
											&ds_datevar.
										%end;
									%end; 
									%else %if %sysevalf(%superq(ds_bydate)=,boolean) eq 0 %then %do;
										&ds_bydate.
									%end;
									%else %if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
										&ds_datevar.
									%end;
									%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
										&ds_categvar.
									%end;
								)
			
				%end;
				indsname=dsn;
				dbname=dsn;
		run;

		%agreementDateRange (templib=&templib.,
							 ds_new=&lib._all,
							 ds_startyr=&ds_startyr.,
						   	 ds_endyr=&ds_endyr.,
						   	 ds_bydate=&ds_bydate.,
							 time = &time.)

		%agreementCleanData ( templib=&templib.,
								 	ds_new=&lib._all,
									ds_linktype=&ds_linktype.,
									ds_byvar=&ds_byvar.,
									ds_datevar=&ds_datevar.,
									ds_categvar=&ds_categvar., 
								 	ref_byvar=&ref_byvar.,
						 		 	ref_datevar=&ref_datevar.,
						 		 	ref_categvar=&ref_categvar.);
	%end;
%mend agreementCreateDb;


/*******************************************************************************************************************************************/
/*Macro to create reference dataset for agreement stats based on information provided by users*/
%macro agreementCreateRefDb (templib=,
							 ref_data=,
							 ref_byvar=,
					 		 ref_datevar=,
					 		 ref_categvar=);
	%local count_rep_ref_byvar;
	data &templib..refdb;
		set &ref_data (keep=
							%if %sysevalf(%superq(ref_byvar)=,boolean) eq 0 %then %do;
								&ref_byvar.
							%end;
							%if %sysevalf(%superq(ref_datevar)=,boolean) eq 0 %then %do;
								&ref_datevar.
							%end;
							%if %sysevalf(%superq(ref_categvar)=,boolean) eq 0 %then %do;
								&ref_categvar.
							%end;
						);

		by &ref_byvar.;
		if last.&ref_byvar.;
		if missing(&ref_byvar.) then delete;

		%if %sysevalf(%superq(ref_datevar)=,boolean) eq 0 %then %do;
			rename &ref_datevar.= refdb_&ref_datevar.;
		%end;
		%if %sysevalf(%superq(ref_categvar)=,boolean) eq 0 %then %do;
			rename	&ref_categvar.=refdb_&ref_categvar.;	
		%end;
	run;
 
	proc sort data=&templib..refdb out=&templib..temp nodupkey;
		by _all_;
	run;

	/*Check to see if reference dataset is unique by ref_byvar. If it is not unique macro exceution will be terminated*/
	proc sql noprint;
		select count(&ref_byvar.) as count into :count_rep_ref_byvar from &templib..temp group by &ref_byvar. having count(&ref_byvar.) gt 1;
	quit;

	%if %sysevalf(%superq(count_rep_ref_byvar)=,boolean) ne 1  and &count_rep_ref_byvar. gt 1 %then %do;
		proc datasets lib=&templib. nolist;
			delete refdb temp;
		run;
		quit;
		%put;
		%put ERROR: &ref_data dataset is not unique by &ref_byvar.;
		%put NOTE: For the execution of macro &ref_data dataset must be unique by &ref_byvar.;
		%put NOTE: Macro will be terminated;
		%put;
		%abort;
	%end;

	proc sort data=&templib..temp out=&templib..refdb;
		by &ref_byvar.;
	run;
		
%mend agreementCreateRefDb;


/*******************************************************************************************************************************************/
%macro agreement(lib=work,
				 templib=work,
				 ds=,
				 ds_prefix=off,
				 ds_crosswalk=,
				 ds_mergeby=,
				 ds_linktype=,
				 ds_startyr=,
				 ds_endyr=,
				 ds_byvar=ikn,
				 ds_bydate=,
				 ds_datevar=,
				 ds_categvar=,
				 ref_data=rpdb.rpdbdemo_level1,
				 ref_byvar=ikn,
				 ref_datevar=bdate,
				 ref_categvar=sex,
				 time=fiscal,
				 path=
				);

	/*-----------------------------------------------------------------------------------------------------------------------------------*/
    /*Macro initialization and checks*/
	/*Save the default users settings*/
	proc optsave key='core\options';
    run;
    ods listing;
    ods graphics off;

	/*Create local variable*/
	%local ds_linktype_flag ori_ds ori_ref_data rc dsid result countds_parts;

	/*Creating global variables relevant to agreement macro*/
	%global agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;

	/*Standaridizng parameter values*/
	%let ds_linktype_flag=0;
	%let ori_ds=&ds.;
	%let ori_ref_data=&ref_data.;

	%if %sysevalf(%superq(ds_prefix)=,boolean) eq 1 %then %do;
		%let ds_prefix=OFF;
	%end;
	%else %do;
		%let ds_prefix=%upcase(&ds_prefix);
	%end;

	%if %sysevalf(%superq(templib)=,boolean) eq 1 %then %do;
		%let templib=work;
	%end;
	%else %do;
		%let templib=%lowcase(&templib);
	%end;

	%let time=%upcase(&time);
	%let lib=%lowcase(&lib);
	%let ds=%lowcase(&ds);
	
	%if %sysevalf(%superq(ds_crosswalk)=,boolean) eq 0 %then %do;
		%let countds_parts=%eval(%sysfunc(countc(&ds_crosswalk.,'.'))+1);
		%if &countds_parts eq 1 %then %let ds_crosswalk=&lib..&ds_crosswalk.;
	%end;

	%let ds_mergeby=%lowcase(&ds_mergeby);
	%let ds_byvar=%lowcase(&ds_byvar);
	%let ds_bydate=%lowcase(&ds_bydate);
	%let ds_datevar=%lowcase(&ds_datevar);
	%let ds_categvar=%lowcase(&ds_categvar);
	%let ds_linktype=%lowcase(&ds_linktype);

	%let ref_data=%lowcase(&ref_data);
	%let ref_byvar=%lowcase(&ref_byvar);
	%let ref_datevar=%lowcase(&ref_datevar);
	%let ref_categvar=%lowcase(&ref_categvar);

	/*-----------------------------------------------------------------------------------------------------------------------------------*/
	/*Initiate parameter value checks*/
	%agreementCheckParam(lib = &lib.,
								templib=&templib.,
								 ds = &ds.,
								 ds_prefix = &ds_prefix.,
								 ds_crosswalk = &ds_crosswalk.,
								 ds_mergeby = &ds_mergeby.,
								 ds_linktype = &ds_linktype.,
								 ds_startyr = &ds_startyr.,
								 ds_endyr = &ds_endyr.,
								 ds_byvar = &ds_byvar.,
								 ds_bydate = &ds_bydate.,
								 ds_datevar = &ds_datevar.,
								 ds_categvar = &ds_categvar.,
								 ref_data = &ref_data.,
								 ref_byvar = &ref_byvar.,
								 ref_datevar = &ref_datevar.,
								 ref_categvar = &ref_categvar.,
								 time = &time.,
								 path = &path.
								);

	/*-----------------------------------------------------------------------------------------------------------------------------------*/
	/*Initiate creation of final dataset for comparing with reference dataset*/
	%agreementCreateDb (lib=&lib.,
						 templib=&templib.,
						 ds=&ds.,
						 ds_prefix=&ds_prefix.,
						 ds_crosswalk=&ds_crosswalk.,
						 ds_mergeby=&ds_mergeby.,
						 ds_linktype=&ds_linktype.,
						 ds_startyr=&ds_startyr.,
						 ds_endyr=&ds_endyr.,
						 ds_byvar=&ds_byvar.,
						 ds_bydate=&ds_bydate.,
						 ds_datevar=&ds_datevar.,
						 ds_categvar=&ds_categvar.,
						 time = &time.,
						 ref_byvar=&ref_byvar.,
				 		 ref_datevar=&ref_datevar.,
				 		 ref_categvar=&ref_categvar.)

	/*Deleting global variables relevant to agreement macro*/
	%symdel agreement_linktype_db agreement_byvar_db agreement_bydate_db agreement_datevar_db agreement_categvar_db;

	/*-----------------------------------------------------------------------------------------------------------------------------------*/
	/*Initiate creation/cleaning of reference dataset*/
	%agreementCreateRefDb (templib=&templib.,
							 ref_data=&ref_data.,
							 ref_byvar=&ref_byvar.,
					 		 ref_datevar=&ref_datevar.,
					 		 ref_categvar=&ref_categvar.);

	/*-----------------------------------------------------------------------------------------------------------------------------------*/
	/*Macro call to determine statistics of agreement between input dataset and reference dataset*/
	/*Create global variable*/
	%global perfect_match_score;
	%let perfect_match_score=3;

	/*Creating a local variable to flag if link_type was not passed by user, hence it would be assumed as Deterministic*/
	%if %sysevalf(%superq(ds_linktype)=,boolean) eq 1 %then %do;
		%let ds_linktype=link_type;
		%let ds_linktype_flag=1;
	%end;

	/*When ds_prefix is OFF and ds is not ALL*/
	%if (&ds_prefix. eq OFF and %upcase(&ds.)  ne ALL) %then %do;
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			%let ds_datevar=&ds._&ds_datevar.;
			%let ref_datevar=refdb_&ref_datevar.;
		%end;
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
			%let ds_categvar=&ds._&ds_categvar.;
			%let ref_categvar=refdb_&ref_categvar.;
		%end;

		%agreement_stats(templib=&templib.,
							ds=&ds.,
							ds_ori=&ds.,
							ds_prefix=&ds_prefix.,
						 	ds_linktype=&ds_linktype.,
						 	ds_byvar=&ds_byvar.,
						 	ds_bydate=&ds_bydate.,
						 	ds_datevar=&ds_datevar.,
						 	ds_categvar=&ds_categvar.,
						 	ref_data=refdb,
						 	ref_byvar=&ref_byvar.,
						 	ref_datevar=&ref_datevar.,
						 	ref_categvar=&ref_categvar.,
						 	time=&time.);
	%end;
	/*When ds_prefix is ON OR when ds_prefix is OFF and ds is ALL*/
	%else  %do;
		%if %sysevalf(%superq(ds_datevar)=,boolean) eq 0 %then %do;
			%let ds_datevar=&lib._all_&ds_datevar.;
			%let ref_datevar=refdb_&ref_datevar.;
		%end;
		%if %sysevalf(%superq(ds_categvar)=,boolean) eq 0 %then %do;
			%let ds_categvar=&lib._all_&ds_categvar.;
			%let ref_categvar=refdb_&ref_categvar.;
		%end;
		%agreement_stats(templib=&templib.,
						ds=&lib._all,
						ds_ori=&ds.,
						ds_prefix=&ds_prefix.,
						ds_linktype=&ds_linktype.,
						ds_byvar=&ds_byvar.,
						ds_bydate=&ds_bydate.,
						ds_datevar=&ds_datevar.,
						ds_categvar=&ds_categvar.,
					    ref_data=refdb,
						ref_byvar=&ref_byvar.,
						ref_datevar=&ref_datevar.,
						ref_categvar=&ref_categvar.,
						time=&time.);
	%end;

	/*-----------------------------------------------------------------------------------------------------------------------------------*/
	/*Macro call to create final report*/
	/*ds_prefix=OFF and ds value as ALL*/
	%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds.) eq ALL) %then %do;
		%agreement_html(templib=&templib.,
					  lib=&lib.,
					  ds=&ds.,
					  ds_prefix=&ds_prefix.,
					  ds_linktype_flag=&ds_linktype_flag.,
					  ds_linktype=&ds_linktype.,
					  ds_datevar=&ds_datevar.,
					  ref_datevar=&ref_datevar.,
					  ds_categvar=&ds_categvar.,
					  ds_bydate=&ds_bydate.,
					  ref_data=&ori_ref_data.,
					  time=&time.,
					  path=&path.,
					  report1=summary_report);/*Generate only summary report*/
			proc datasets lib=&templib. nolist;
				delete  refdb summary_report merged_inds_refds temp;
			run;
			quit;
	%end;
	%else %do;
		%if (%sysevalf(%superq(ds_datevar)=,boolean) eq 1) %then %do;
			%agreement_html(templib=&templib.,
						  lib=&lib.,
						  ds=&ds.,
						  ds_prefix=&ds_prefix.,
						  ds_linktype_flag=&ds_linktype_flag.,
						  ds_linktype=&ds_linktype.,
						  ds_datevar=&ds_datevar.,
						  ref_datevar=&ref_datevar.,
						  ds_categvar=&ds_categvar.,
						  ds_bydate=&ds_bydate.,
						  ref_data=&ori_ref_data.,
						  time=&time.,
						  path=&path.,
						  report1=summary_report,
						  report2=yr_based_report);

			proc datasets lib=&templib. nolist;
				delete  refdb summary_report yr_based_report merged_inds_refds temp;
			run;
			quit;
		%end;
		%else %do;
			%agreement_html(templib=&templib.,
						  lib=&lib.,
						  ds=&ds.,
						  ds_prefix=&ds_prefix.,
						  ds_linktype_flag=&ds_linktype_flag.,
						  ds_linktype=&ds_linktype.,
						  ds_datevar=&ds_datevar.,
						  ref_datevar=&ref_datevar.,
						  ds_categvar=&ds_categvar.,
						  ds_bydate=&ds_bydate.,
						  ref_data=&ori_ref_data.,
						  time=&time.,
						  path=&path.,
						  report1=summary_report,
						  report2=yr_based_report,
						  report3=bland_altman_app);

			proc datasets lib=&templib. nolist;
				delete  refdb summary_report yr_based_report bland_altman_app merged_inds_refds temp;
			run;
			quit;
		%end;
	%end;

	/*-----------------------------------------------------------------------------------------------------------------------------------*/
	/*Reset all user settings and cleaning temporary library*/
	/*Restore the default users settings*/
	proc optload key='core\options';
   	run;

	%if (%upcase(&ds_prefix.) eq OFF and %upcase(&ds.) eq ALL) %then %do;
		proc datasets lib=&templib. nolist;
			delete  &lib._all;
		run;
		quit;
	%end;
	%else %do;
		%if (%upcase(&ds_prefix.) eq ON) %then %do;
			proc datasets lib=&templib. nolist;
				delete  &lib._all;
			run;
			quit;
		%end;
		%else %do;
			proc datasets lib=&templib. nolist;
				delete  &ds.;
			run;
			quit;
		%end;

	%end;

	%symdel perfect_match_score;
%mend agreement;
