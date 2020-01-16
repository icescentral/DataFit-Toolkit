/*========================================================================  
DataFit Toolkit - Macro for creating simulated data 
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

/******************************************************************************************************************************
*******************************************************************************************************************************
*******************************************************************************************************************************
Program				: createSimulatedData
Purpose				: Generate a simulated data that can be used for demonstration/presentation of DQ tools outside of ICES.
Details				: This program generates simulated data with number of observation as specified by the user and populates
			  		  about 21 variables. It also includes various errors that are captured by DQ tools.
Programmer			: Gangamma Kalappa
Date      			: 24-July-2015
Update       		 : 10-May-2018 (Sean Ji)
						- add the birthdate variable
						- introduced the erros for the variables, birthdate and sex
***************************************************    USAGE DETAILS               ********************************************
%createSimulatedData (	nobs=,
					endyr=,
					noyrs=)
						nobs  = Total number of observations that you would require to have in your simulated data
						endyr = Specify the end year of the fiscal year that would like to create the data for
		    			noyrs = Specify the number of fiscal  years for which you would like to create the data for

Example1:
%createSimulatedData (	nobs=800000,
					endyr=2014,
					noyrs=1)
           				- Creates dataset with 800000 observations and with ddate for the fiscal year 2013/2014

Example2:
%createSimulatedData (	nobs=1800000,
					endyr=2014,
					noyrs=10)
           				- Creates dataset with 1800000 observations and with ddate from the fiscal year 2003/2004 to 2013/2014

Note				: Re-running the program for the same input will not result in same dataset; as the date and time variables
					  are assigned randomly
*******************************************************************************************************************************
*******************************************************************************************************************************
******************************************************************************************************************************/


/*Retrieve number of observations*/
%macro retrieveObs (interds=);
	%local  dsid  rc;
	%let internobs=0;
	%let dsid=%sysfunc(open(&interds));
	%let internobs=%sysfunc(attrn(&dsid,nobs));
	%let rc=%sysfunc(close(&dsid));
%mend retrieveObs;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to check parameter values*/
%macro initialize_checks (	nobs=,
							endyr=,
							noyrs=);

	%if %sysevalf(%superq(nobs)=,boolean) %then %do;
		%put "Parameter specifying number observations to be created has missing value. Rerun the program with correct value";
		%abort;
	%end;
	%else %do;
		%if &nobs le 0 %then %do;
			%put "Parameter specifying number observations has to be greater than zero. Rerun the program with correct value";
			%abort;
		%end;
		%else %do;
			%if &nobs lt 500000 %then %do;
				%put "Parameter specifying number observations has to be atleast 500000. Rerun the program with correct value";
				%abort;
			%end;
		%end;
	%end;

	%if %sysevalf(%superq(endyr)=,boolean) %then %do;
		%put "Parameter specifying end year has missing value. Rerun the program with correct value";
		%abort;
	%end;
	%else %do;
		%if &endyr le 1980 %then %do;
			%put "Parameter specifying end year has to be greater than 1980. Rerun the program with correct value";
			%abort;
		%end;
	%end;

	%if %sysevalf(%superq(noyrs)=,boolean) %then %do;
		%put "Parameter specifying number of years for which data set needs to be created has missing value. Rerun the program with correct value";
		%abort;
	%end;
	%else %do;
		%if &noyrs lt 10 %then %do;
			%put "Parameter specifying number of years for which data set needs to be created has to be atleast 10. Rerun the program with correct value";
			%abort;
		%end;
	%end;
%mend initialize_checks;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Generate pat_id */
%macro createPatId (nobs=);
	%local nsample totalobs;

	data hospitalization;
		length pat_id $12 key $20 pat_idtype $1;
		do nbs=1 to int(.7734*&nobs);
			do i=1 to 12;
				rannum=int(ranuni(7654321)*9+1);
				substr(pat_id,i,1)=rannum;
			end;
			output;
		end;
		keep pat_id pat_idtype;
	run;

	proc sql noprint;
		create table unique_patid as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
	quit;
	%let nsample=%sysfunc(int(%sysevalf(0.105*&nobs)));
	proc surveyselect data=unique_patid out=temp method=srs sampsize=&nsample seed=7654321;
	run;
	data hospitalization;
		set hospitalization temp;
	run;

	proc sql noprint;
		create table unique_patid as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
	quit;
	%let nsample=%sysfunc(int(%sysevalf(0.0334*&nobs)));
	proc surveyselect data=unique_patid out=temp method=srs sampsize=&nsample seed=7654321;
	run;
	data hospitalization;
		set hospitalization temp temp;
	run;

	proc sql noprint;
		create table unique_patid as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
	quit;
	%let nsample=%sysfunc(int(%sysevalf(0.015*&nobs)));
	proc surveyselect data=unique_patid out=temp method=srs sampsize=&nsample seed=7654321;
	run;
	data hospitalization;
		set hospitalization temp temp temp;
	run;

	%retrieveObs (interds=hospitalization)
	%let totalobs=%sysfunc(int(%sysevalf(&nobs-&internobs)));
	proc sql noprint;
		create table unique_patid as
		select distinct pat_id from hospitalization ;
	quit;

	data hospitalization;
		set hospitalization unique_patid(obs=&totalobs);
		pat_idtype ="V";
	run;
%mend createPatId;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating the 'key' variable*/
%macro createKey;
	data hospitalization;
		set hospitalization;
		key=put(year(today()),4.)||put(month(today()),z2.)||put(_n_,z14.);
	run;
%mend createKey;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating the 'chart_num' variable*/
%macro createChartNum;
	data hospitalization;
		set hospitalization;
		chart_num=key;
	run;
%mend createChartNum;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating  age category variable*/
%macro createAgeCat ();
	data hospitalization;
		length agecat $1;
		set hospitalization;
		if age >=0 and age <=17 then agecat='1';
		else if age >=18 and age <=69 then agecat='2';
		else if age >=70 then agecat='3';
	run;
%mend createAgeCat;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating  age unit variable*/
%macro createAgeUnit ();
	data hospitalization (drop=temp);
		length ageunit $3;
		set hospitalization;
		if age=0 and agecode="B" then ageunit="000";
		else if age >=2 then ageunit=put(age,z3.);
		else do;
			if agecode="D" then do;
				temp= int(ranuni(7654321)*30+1);
				ageunit=put(temp,z3.);
			end;
			else if agecode="M" then do;
				temp= int(ranuni(7654321)*23+1);
				ageunit=put(temp,z3.);
			end;
		end;
	run;
%mend createAgeUnit;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating  age code variable*/
%macro createAgeCode (nobs=);
	proc sql noprint;
		create table subset_1 as
		select * from hospitalization where age eq 0;
  		create table subset_2 as
		select * from hospitalization where age ne 0;
	quit;

	%retrieveObs (interds=subset_1)
	data subset_1a subset_1b;
		length agecode $1;
		set subset_1;
		if _n_ le int(0.8651*&internobs) then do;
			agecode="B";
			output subset_1a;	
		end;
		else output subset_1b;
	run;

	%retrieveObs (interds=subset_1b)
	data subset_1b;
		set subset_1b;
		if _n_  le int(0.50*&internobs) then do;
			 agecode ="D";
		end;
		else do;
			 agecode ="M";
		end;
	run;

	data subset_1;
		set subset_1a subset_1b;
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;

	data hospitalization;
		set hospitalization;
		if missing(agecode) then do;
			if age eq 1 then agecode="M";
			else agecode="Y";
		end;
	run;
%mend createAgeCode;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating  age related variable*/
%macro createAgeVar (nobs=,
				     endyr=);
	proc sql noprint;
		create table subset_1 as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
  		create table subset_2 as
		select * from hospitalization group by pat_id having count(pat_id) gt 1;
	quit;


	%retrieveObs (interds=subset_1)
	data subset_1a subset_1b;
		set subset_1;
		if _n_  le int(0.2317*&internobs) then do; 
			age=0;
			output subset_1a;
		end;
		else if _n_  gt int(0.2317*&internobs) and  _n_  lt int(0.3163*&internobs) then do; 
			age = int(ranuni(7654321)*6)+25;
			output subset_1a;
		end;
		else if _n_  gt int(0.3163*&internobs) and  _n_  lt int(0.7188*&internobs) then do; 
			age = int(ranuni(7654321)*35+53);
			output subset_1a;
		end;
		else do;
			output subset_1b;

		end;
	run;

	%retrieveObs (interds=subset_1b)
	data subset_1b;
		set subset_1b;
		if _n_  le int(0.0166*&internobs) then do;
			age = 1;
		end;
		else if _n_ gt int(0.0166*&internobs) and  _n_  le int(0.0283*&internobs) then  do;
			age = 2;
		end;
		else if _n_ gt int(0.0283*&internobs) and  _n_  le int(0.0559*&internobs) then  do;
			age = int(ranuni(7654321)*3+3);
		end;
		else if _n_ gt int(0.0559*&internobs) and  _n_  le int(0.1022*&internobs) then  do;
			age = int(ranuni(7654321)*8+6);
		end;
		else if _n_ gt int(0.1022*&internobs) and  _n_  le int(0.2243*&internobs) then  do;
			age = int(ranuni(7654321)*9+14);
		end;
		else if _n_ gt int(0.2243*&internobs) and  _n_  le int(0.2674*&internobs) then  do;
			age = int(ranuni(7654321)*2+23);
		end;
		else if _n_ gt int(0.2674*&internobs) and  _n_  le int(0.3984*&internobs) then  do;
			age = int(ranuni(7654321)*3+31);
		end;
		else if _n_ gt int(0.3984*&internobs) and  _n_  le int(0.5045*&internobs) then  do;
			age = int(ranuni(7654321)*3+34);
		end;
		else if _n_ gt int(0.5045*&internobs) and  _n_  le int(0.6028*&internobs) then  do;
			age = int(ranuni(7654321)*4+37);
		end;
		else if _n_ gt int(0.6028*&internobs) and  _n_  le int(0.715*&internobs) then  do;
			age = int(ranuni(7654321)*6+41);
		end;
		else if _n_ gt int(0.715*&internobs) and  _n_  le int(0.8593*&internobs) then  do;
			age = int(ranuni(7654321)*6+47);
		end;
		else if _n_ gt int(0.8593*&internobs) and  _n_  le int(0.9277*&internobs) then  do;
			age = int(ranuni(7654321)*3+88);
		end;
		else if _n_ gt int(0.9277*&internobs) and  _n_  le int(0.9718*&internobs) then  do;
			age = int(ranuni(7654321)*3+91);
		end;
		else if _n_ gt int(0.9718*&internobs) and  _n_  le int(0.9856*&internobs) then  do;
			age = int(ranuni(7654321)*2+94);
		end;
		else do;
			age = int(ranuni(7654321)*7+96);
		end;
	run;

	data subset_1;
		set subset_1a  subset_1b;
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;

	proc sql noprint;
		create table subset_1 as
		select * from hospitalization where age is not missing;
  		create table subset_2 as
		select * from hospitalization where age is missing;
	quit;

	proc sql noprint;
		create table subset_2a as
		select distinct pat_id from subset_2 ;
	quit;

	%retrieveObs (interds=subset_2a)
	data subset_2a;
		set subset_2a;
		if _n_  le int(0.0116*&internobs) then do;
			age = int(ranuni(7654321)*2+0);
		end;
		else if _n_ gt int(0.0116*&internobs) and  _n_  le int(0.0217*&internobs) then  do;
			age = int(ranuni(7654321)*4+2);
		end;
		else if _n_ gt int(0.0217*&internobs) and  _n_  le int(0.031*&internobs) then  do;
			age = int(ranuni(7654321)*6+6);
		end;
		else if _n_ gt int(0.031*&internobs) and  _n_  le int(0.0359*&internobs) then  do;
			age = int(ranuni(7654321)*2+12);
		end;
		else if _n_ gt int(0.0359*&internobs) and  _n_  le int(0.054*&internobs) then  do;
			age = int(ranuni(7654321)*4+14);
		end;
		else if _n_ gt int(0.054*&internobs) and  _n_  le int(0.0774*&internobs) then  do;
			age = int(ranuni(7654321)*7+18);
		end;
		else if _n_ gt int(0.0774*&internobs) and  _n_  le int(0.0905*&internobs) then  do;
			age = int(ranuni(7654321)*3+25);
		end;
		else if _n_ gt int(0.0905*&internobs) and  _n_  le int(0.1829*&internobs) then  do;
			age = int(ranuni(7654321)*17+28);
		end;
		else if _n_ gt int(0.1829*&internobs) and  _n_  le int(0.212*&internobs) then  do;
			age = int(ranuni(7654321)*4+45);
		end;
		else if _n_ gt int(0.212*&internobs) and  _n_  le int(0.231*&internobs) then  do;
			age = int(ranuni(7654321)*2+49);
		end;
		else if _n_ gt int(0.231*&internobs) and  _n_  le int(0.3597*&internobs) then  do;
			age = int(ranuni(7654321)*10+51);
		end;
		else if _n_ gt int(0.3597*&internobs) and  _n_  le int(0.4468*&internobs) then  do;
			age = int(ranuni(7654321)*5+61);
		end;
		else if _n_ gt int(0.4468*&internobs) and  _n_  le int(0.605*&internobs) then  do;
			age = int(ranuni(7654321)*8+66);
		end;
		else if _n_ gt int(0.605*&internobs) and  _n_  le int(0.8829*&internobs) then  do;
			age = int(ranuni(7654321)*13+74);
		end;
		else if _n_ gt int(0.8829*&internobs) and  _n_  le int(0.9747*&internobs) then  do;
			age = int(ranuni(7654321)*6+87);
		end;
		else if _n_ gt int(0.9747*&internobs) and  _n_  le int(0.9877*&internobs) then  do;
			age = int(ranuni(7654321)*2+93);
		end;
		else if _n_ gt int(0.9877*&internobs) and  _n_  le int(0.9966*&internobs) then  do;
			age = int(ranuni(7654321)*3+95);
		end;
		else do;
			age = int(ranuni(7654321)*6+97);
		end;
	run;

	proc sql noprint;
		create table  subset_2a_temp as
		select a.pat_id,a.pat_idtype,a.key,b.age from subset_2 as a, subset_2a as b 
				where a.pat_id eq b.pat_id;
	quit;

	data hospitalization;
		set subset_1 subset_2a_temp;
	run;
%mend createAgeVar;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating admdate, admtime, ddate, dtime variables*/
%macro createDateVarUniqueId (ds=);
	proc sql noprint;
		create table subset_1a as
		select * from &ds where agecode eq "B";
		create table subset_1b as
		select * from &ds where agecode ne "B";
		create table subset_1b_1 as
		select * from subset_1b where agecode in ("M","D");
		create table subset_1b_2 as
		select * from subset_1b where agecode not in ("M","D");
	quit;

	%retrieveObs (interds=subset_1a)
	data subset_1a (drop= dinterval);
		set subset_1a;

		admdate=mindate+int(ranuni(7654321)*range);
		format admdate date9.;
		admtime=dhms(admdate,hh,mm,ss);
		format admtime datetime15.;

		if  _n_ le int(0.3904*&internobs) then do;
			dinterval=1;
		end;
		else if _n_  gt int(0.3904*&internobs) and _n_  le int(0.7476*&internobs) then do;
			dinterval=2;
		end;
		else if _n_  gt int(0.7476*&internobs) and _n_  le int(0.8776*&internobs) then do;
			dinterval=3;
		end;
		else if _n_  gt int(0.8776*&internobs) and _n_  le int(0.9096*&internobs) then do;
			dinterval=4;
		end;
		else if _n_  gt int(0.9096*&internobs) and _n_  le int(0.9196*&internobs) then do;
			dinterval=5;
		end;
		else do;
			dinterval=int(ranuni(7654321)*30)+6;
		end;

		format ddate date9.;
		ddate=intnx('day',admdate,dinterval);
		dtime=dhms(ddate,d_hh,d_mm,d_ss);
		format dtime datetime15.;
		if ddate gt "31Mar&endyr"d then do;
			ddate="31Mar&endyr"d;
		
			if d_hh lt hh then do;
				d_hh=23;
				d_mm=59;
				d_ss=59;
				dtime=dhms(ddate,d_hh,d_mm,d_ss);
				format dtime datetime15.;
			end;
		end;
	run;

	data subset_1b_1 (drop= dinterval);
		set subset_1b_1;

		%retrieveObs (interds=subset_1b_1)
		admdate=mindate+int(ranuni(7654321)*range);
		format admdate date9.;
		admtime=dhms(admdate,hh,mm,ss);
		format admtime datetime15.;

		if  _n_ le int(0.3998*&internobs) then do;
			dinterval=1;
		end;
		else if _n_  gt int(0.3998*&internobs) and _n_  le int(0.6122*&internobs) then do;
			dinterval=2;
		end;
		else if _n_  gt int(0.6122*&internobs) and _n_  le int(0.7415*&internobs) then do;
			dinterval=3;
		end;
		else if _n_  gt int(0.7415*&internobs) and _n_  le int(0.7987*&internobs) then do;
			dinterval=4;
		end;
		else if _n_  gt int(0.7987*&internobs) and _n_  le int(0.8278*&internobs) then do;
			dinterval=5;
		end;
		else if _n_  gt int(0.8278*&internobs) and _n_  le int(0.8589*&internobs) then do;
			dinterval=6;
		end;
		else do;
			dinterval=int(ranuni(7654321)*29)+7;
		end;

		format ddate date9.;
		ddate=intnx('day',admdate,dinterval);
		dtime=dhms(ddate,d_hh,d_mm,d_ss);
		format dtime datetime15.;
		if ddate gt "31Mar&endyr"d then do;
			ddate="31Mar&endyr"d;
		
			if d_hh lt hh then do;
				d_hh=23;
				d_mm=59;
				d_ss=59;
				dtime=dhms(ddate,d_hh,d_mm,d_ss);
				format dtime datetime15.;
			end;
		end;
	run;

	data subset_1b_2 (drop= dinterval);
		set subset_1b_2;

		%retrieveObs (interds=subset_1b_2)
		admdate=mindate+int(ranuni(7654321)*range);
		format admdate date9.;
		admtime=dhms(admdate,hh,mm,ss);
		format admtime datetime15.;

		if  _n_ le int(0.2743*&internobs) then do;
			dinterval=1;
		end;
		else if _n_  gt int(0.2743*&internobs) and _n_  le int(0.4947*&internobs) then do;
			dinterval=2;
		end;
		else if _n_  gt int(0.4947*&internobs) and _n_  le int(0.6498*&internobs) then do;
			dinterval=3;
		end;
		else if _n_  gt int(0.6498*&internobs) and _n_  le int(0.7409*&internobs) then do;
			dinterval=4;
		end;
		else if _n_  gt int(0.7409*&internobs) and _n_  le int(0.7926*&internobs) then do;
			dinterval=5;
		end;
		else if _n_  gt int(0.7926*&internobs) and _n_  le int(0.8556*&internobs) then do;
			dinterval=6;
		end;
		else if _n_  gt int(0.8556*&internobs) and _n_  le int(0.9029*&internobs) then do;
			dinterval=7;
		end;
		else do;
			dinterval=int(ranuni(7654321)*28)+8;
		end;

		format ddate date9.;
		ddate=intnx('day',admdate,dinterval);
		dtime=dhms(ddate,d_hh,d_mm,d_ss);
		format dtime datetime15.;
		if ddate gt "31Mar&endyr"d then do;
			ddate="31Mar&endyr"d;
		
			if d_hh lt hh then do;
				d_hh=23;
				d_mm=59;
				d_ss=59;
				dtime=dhms(ddate,d_hh,d_mm,d_ss);
				format dtime datetime15.;
			end;
		end;
	run;

	data subset_1;
		set subset_1a subset_1b_1 subset_1b_2;
	run;
%mend createDateVarUniqueId;

%macro createIntermediateDateVarDupId (inds=,
									   outds=);
	%retrieveObs (interds=&inds)
	data &outds (drop= dinterval lag_ddate);
		set &inds;
		if missing(admdate) and not missing(lag_ddate) then do;
			if _n_  le int(0.1437*&internobs) then do;
				admdate=lag_ddate;
			end;
			else if _n_  gt int(0.1437*&internobs) and _n_  le int(0.1839*&internobs) then do;
				admdate=lag_ddate+1;
			end;
			else if _n_  gt int(0.1839*&internobs) and _n_  le int(0.2176*&internobs) then do;
				admdate=lag_ddate+2;
			end;
			else if _n_  gt int(0.2176*&internobs) and _n_  le int(0.2376*&internobs) then do;
				admdate=lag_ddate+3;
			end;
			else if _n_  gt int(0.2376*&internobs) and _n_  le int(0.2576*&internobs) then do;
				admdate=lag_ddate+4;
			end;
			else if _n_  gt int(0.2576*&internobs) and _n_  le int(0.2676*&internobs) then do;
				admdate=lag_ddate+5;
			end;
			else do;
				admdate=lag_ddate+int(ranuni(7654321)*82)+6;
			end;
				
			if admdate gt "31Mar&endyr"d then admdate="31Mar&endyr"d;
			format admdate date9.;
			admtime=dhms(admdate,hh,mm,ss);
			format admtime datetime15.;
			
			if _n_  le int(0.3095*&internobs) then do;
				dinterval=1;
			end;
			else if _n_  gt int(0.3095*&internobs) and _n_  le int(0.462*&internobs) then do;
				dinterval=2;
			end;
			else if _n_  gt int(0.462*&internobs) and _n_  le int(0.5876*&internobs) then do;
				dinterval=3;
			end;
			else if _n_  gt int(0.5876*&internobs) and _n_  le int(0.7036*&internobs) then do;
				dinterval=4;
			end;
			else if _n_  gt int(0.7036*&internobs) and _n_  le int(0.7936*&internobs) then do;
				dinterval=5;
			end;
			else if _n_  gt int(0.7936*&internobs) and _n_  le int(0.8436*&internobs) then do;
				dinterval=6;
			end;
			else do;
				dinterval=int(ranuni(7654321)*84)+7;
			end;
				
			format ddate date9.;
			ddate=intnx('day',admdate,dinterval);
			dtime=dhms(ddate,d_hh,d_mm,d_ss);
			format dtime datetime15.;
			if ddate gt "31Mar&endyr"d then do;
				ddate="31Mar&endyr"d;
		
				if d_hh lt hh then do;
					d_hh=23;
					d_mm=59;
					d_ss=59;
					dtime=dhms(ddate,d_hh,d_mm,d_ss);
					format dtime datetime15.;
				end;
			end;
		end;
	run;
%mend createIntermediateDateVarDupId;

%macro createDateVarDupId (ds=);
	proc sort data=subset_2;
		by pat_id;
	run;

	data subset_2_1 subset_2_2;
		set subset_2;
		by pat_id;
		if first.pat_id then output subset_2_1;
		else output subset_2_2;
	run;

	%retrieveObs (interds=subset_2_1)
	data subset_2_1 (drop= dinterval);
		set subset_2_1;

		admdate=mindate+int(ranuni(7654321)*range);
		format admdate date9.;
		admtime=dhms(admdate,hh,mm,ss);
		format admtime datetime15.;

		if  _n_ le int(0.245*&internobs) then do;
			dinterval=1;
		end;
		else if _n_  gt int(0.245*&internobs) and _n_  le int(0.4063*&internobs) then do;
			dinterval=2;
		end;
		else if _n_  gt int(0.4063*&internobs) and _n_  le int(0.5433*&internobs) then do;
			dinterval=3;
		end;
		else if _n_  gt int(0.5433*&internobs) and _n_  le int(0.6633*&internobs) then do;
			dinterval=4;
		end;
		else if _n_  gt int(0.6633*&internobs) and _n_  le int(0.759*&internobs) then do;
			dinterval=5;
		end;
		else if _n_  gt int(0.759*&internobs) and _n_  le int(0.8244*&internobs) then do;
			dinterval=6;
		end;
		else if _n_  gt int(0.8244*&internobs) and _n_  le int(0.8943*&internobs) then do;
			dinterval=7;
		end;
		else do;
			dinterval=int(ranuni(7654321)*28)+8;
		end;

		format ddate date9.;
		ddate=intnx('day',admdate,dinterval);
		dtime=dhms(ddate,d_hh,d_mm,d_ss);
		format dtime datetime15.;
		if ddate gt "31Mar&endyr"d then do;
			ddate="31Mar&endyr"d;
		
			if d_hh lt hh then do;
				d_hh=23;
				d_mm=59;
				d_ss=59;
				dtime=dhms(ddate,d_hh,d_mm,d_ss);
				format dtime datetime15.;
			end;
		end;
	run;

	data subset_2;
		set subset_2_1 subset_2_2;
	run;

	proc sort data=subset_2;
		by pat_id;
	run;

	proc sql noprint;
		create table subset_2_1 as
		select * from subset_2 group by pat_id having count(pat_id) eq 2;
		create table subset_2_2 as
		select * from subset_2 group by pat_id having count(pat_id) gt 2;
	quit;

	proc sort data=subset_2_1;
		by pat_id;
	run;

	data subset_2_1a (drop=temp_date);
		set subset_2_1;
		by pat_id;
		if first.pat_id then do;
			retain temp_date;
			temp_date=ddate;
		end;
		if last.pat_id then do;
			lag_ddate=temp_date;
		end;
		format lag_ddate date9.;
	run;

	%createIntermediateDateVarDupId (inds=subset_2_1a,
									 outds=subset_2_1)

	data subset_2_2a subset_2_2b;
		set subset_2_2;
		if not missing(admdate) then output subset_2_2a;
		else output subset_2_2b;
	run;

	proc sort data=subset_2_2b;
		by pat_id key;
	run;

	%retrieveObs (interds=subset_2_2b)
	data subset_2_2b_temp (drop= dinterval);
		set subset_2_2b;
		by pat_id key;

		if last.pat_id then do;
			call missing(admdate);
			call missing(admtime);
			call missing(ddate);
			call missing(dtime);
		end;
        else do;
			admdate=mindate+int(ranuni(7654321)*range);
			format admdate date9.;
			admtime=dhms(admdate,hh,mm,ss);
			format admtime datetime15.;

			if  _n_ le int(0.2743*&internobs) then do;
				dinterval=1;
			end;
			else if _n_  gt int(0.2743*&internobs) and _n_  le int(0.4947*&internobs) then do;
				dinterval=2;
			end;
			else if _n_  gt int(0.4947*&internobs) and _n_  le int(0.6498*&internobs) then do;
				dinterval=3;
			end;
			else if _n_  gt int(0.6498*&internobs) and _n_  le int(0.7409*&internobs) then do;
				dinterval=4;
			end;
			else if _n_  gt int(0.7409*&internobs) and _n_  le int(0.7926*&internobs) then do;
				dinterval=5;
			end;
			else if _n_  gt int(0.7926*&internobs) and _n_  le int(0.8556*&internobs) then do;
				dinterval=6;
			end;
			else if _n_  gt int(0.8556*&internobs) and _n_  le int(0.9029*&internobs) then do;
				dinterval=7;
			end;
			else do;
				dinterval=int(ranuni(7654321)*28)+8;
			end;

			format ddate date9.;
			ddate=intnx('day',admdate,dinterval);
			dtime=dhms(ddate,d_hh,d_mm,d_ss);
			format dtime datetime15.;
			if ddate gt "31Mar&endyr"d then do;
				ddate="31Mar&endyr"d;
		
				if d_hh lt hh then do;
					d_hh=23;
					d_mm=59;
					d_ss=59;
					dtime=dhms(ddate,d_hh,d_mm,d_ss);
					format dtime datetime15.;
				end;
			end;
		end;
	run;

	data subset_2_2b;
		set subset_2_2b_temp ;
	run;

	proc sort data=subset_2_2b;
		by pat_id descending admdate;
	run;

	data subset_2_2b_temp (drop=temp_date);
		set subset_2_2b;
		by pat_id;
		if first.pat_id then do;
			retain temp_date;
			temp_date=ddate;
		end;
		if last.pat_id then do;
			lag_ddate=temp_date;
		end;
		format lag_ddate date9.;
	run;

	%createIntermediateDateVarDupId (inds=subset_2_2b_temp,
									 outds=subset_2_2b)

	data subset_2_2;
		set subset_2_2a subset_2_2b;
	run;
	
	data subset_2;
		set subset_2_1 subset_2_2;
	run;
%mend createDateVarDupId;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to create date realted variables*/
%macro createDateVar (nobs=,
				      endyr=,
					  noyrs=);
	data hospitalization;
		set hospitalization;
		mindate="01Apr%eval(&endyr-&noyrs)"d;
		maxdate="31Mar&endyr"d;
		range=maxdate-mindate+1;
		hh=int(ranuni(1)*23+1);
		mm=int(ranuni(2)*60+1);
		ss=int(ranuni(3)*60+1);
		d_hh=int(ranuni(1)*17+9);
		d_mm=int(ranuni(2)*60+1);
		d_ss=int(ranuni(3)*60+1);
		format maxdate mindate date9.;
	run;

	proc sql noprint;
		create table subset_1 as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
  		create table subset_2 as
		select * from hospitalization group by pat_id having count(pat_id) gt 1;
	quit;

	%createDateVarUniqueId (ds=subset_1)
	%createDateVarDupId (ds=subset_2)

	data hospitalization (drop= maxdate mindate range hh mm ss d_hh d_mm d_ss);
		set subset_1 subset_2;
	run;
%mend createDateVar;

/*-----------------------------------------------------------------------------------------------------------------------------*/
/* Added by Sean on May 11, 2018 */
/*Macro to create the birth_date variable based on the admdate*/
%macro createBirthDateVar (ds = hospitalization);
  proc sort data = &ds.(where=(pat_id is not missing))
            out  = _temp;
    by pat_id admdate;
  run;

  proc sort data=_temp out= _temp_uniq nodupkey;
    by pat_id;
  run;

  data _temp_uniq(drop=day);
    set _temp_uniq(keep=pat_id admdate age);
    birthdate = intnx('year', admdate, -1*(age+1), 'sameday' );
    day = day(admdate);
    birthdate = birthdate + int(ranuni(2018) * day + 120);
/*    birthdate = floor(admdate - age * 365.25);*/
    format
      birthdate date9.
    ;
  run;

  proc sql;
    create table _tempout as
      select 
         a.*
        ,b.birthdate
      from
        &ds.         a
        left join
        _temp_uniq   b
        on
        a.pat_id = b.pat_id
      ;
  quit;

  data &ds;
    set _tempout;
  run;

  proc datasets lib=work nolist nodetails;
    delete _temp _temp_uniq _tempout;
  run;


%mend createBirthDateVar;
/* Added end */

/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Create Insttype variable*/
%macro createInstType (nobs=);
	data hospitalization;
		length insttype $2;
		set hospitalization;
	run;
	
	proc sql noprint;
		create table subset_1 as
		select * from hospitalization where age ge 1 and age le 18;
		create table subset_2 as
		select * from hospitalization where age gt 36 ;
		create table subset_3 as
		select * from hospitalization where age eq 0 or (age between 19 and 36);
	quit;

   	proc sql noprint;
		create table unique_patid as
		select distinct pat_id,age,insttype from subset_1;
		create table unique_patid_1 as
		select * from unique_patid where age ge 13;
		create table unique_patid_2 as
		select * from unique_patid where age lt 13;
	quit;

	proc sql noprint;
		create table temp as
		select *, count(age) as max_count from unique_patid_1 group by age;
	quit;

	proc sort data=temp out=unique_patid_1;
		by age;
	run;

	data temp;
		set unique_patid_1;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 13 then do;
			if count le int(0.9911*max_count) then insttype="AT";
		end;
		else if age eq 14 then do;
			if count le int(0.9952*max_count) then insttype="AT";
		end;
		else if age eq 15 then do;
			if count le int(0.9941*max_count) then insttype="AT";
		end;
		else if age eq 16 then do;
			if count le int(0.9952*max_count) then insttype="AT";
		end;
		else if age eq 17 then do;
			if count le int(0.9973*max_count) then insttype="AT";
		end;
		else if age eq 18 then do;
			if count le int(0.999*max_count) then insttype="AT";
		end;
	run;

	data unique_patid_1;
		set temp (drop=max_count count);
		by age;
		if missing(insttype) then insttype="SR";
	run;

	proc sql noprint;
		create table temp as
		select *, count(age) as max_count from unique_patid_2 group by age;
	quit;

	proc sort data=temp out=unique_patid_2;
		by age;
	run;

	data temp;
		set unique_patid_2;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 1 then do;
			if count le int(0.9988*max_count) then insttype="AT";
		end;
		else if age eq 2 then do;
			if count le int(0.9972*max_count) then insttype="AT";
		end;
		else if age eq 3 then do;
			if count le int(0.9986*max_count) then insttype="AT";
		end;
		else if age eq 4 then do;
			if count le int(0.9959*max_count) then insttype="AT";
		end;
		else if age eq 5 then do;
			if count le int(0.9987*max_count) then insttype="AT";
		end;
		else if age eq 6 then do;
			if count le int(0.9981*max_count) then insttype="AT";
		end;
		else if age eq 7 then do;
			if count le int(0.9949*max_count) then insttype="AT";
		end;
		else if age eq 8 then do;
			if count le int(0.9957*max_count) then insttype="AT";
		end;
		else if age eq 9 then do;
			if count le int(0.9950*max_count) then insttype="AT";
		end;
		else if age eq 10 then do;
			if count le int(0.9912*max_count) then insttype="AT";
		end;
		else if age eq 11 then do;
			if count le int(0.9987*max_count) then insttype="AT";
		end;
		else if age eq 12 then do;
			if count le int(0.9929*max_count) then insttype="AT";
		end;
	run;

	data unique_patid_2;
		set temp (drop=max_count count);
		by age;
		if missing(insttype) then insttype="SR";
	run;
		
	data unique_patid;
		set unique_patid_1 unique_patid_2;
	run;

	proc sql noprint;
		create table subset_1_temp as
		select a.*,b.insttype as new_inst from subset_1 as a, unique_patid as b
				where a.pat_id eq b.pat_id;
	quit;

	data subset_1;
		set subset_1_temp;
		drop insttype;
		rename new_inst=insttype;
	run;

	proc sql noprint;
		create table unique_patid as
		select distinct pat_id,age,insttype from subset_2;
		create table unique_patid_1 as
		select * from unique_patid where age between 70 and 80;
		create table unique_patid_2 as
		select * from unique_patid where age not between 70 and 80;
	quit;

	proc sql noprint;
		create table temp as
		select *, count(age) as max_count from unique_patid_1 group by age;
	quit;
	proc sort data=temp out=unique_patid_1;
		by age;
	run;

	data temp;
		set unique_patid_1;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 70 then do;
			if count le int(0.9988*max_count) then insttype="AT";
		end;
		else if age eq 71 then do;
			if count le int(0.9984*max_count) then	insttype="AT";
		end;
		else if age eq 72 then do;
			if count le int(0.9989*max_count) then insttype="AT";
		end;
		else if age eq 73 then do;
			if count le int(0.9993*max_count) then insttype="AT";
		end;
		else if age eq 74 then do;
			if count le int(0.9990*max_count) then insttype="AT";
		end;
		else if age eq 75 then do;
			if count le int(0.9988*max_count) then insttype="AT";
		end;
		else if age eq 76 then do;
			if count le int(0.9989*max_count) then	insttype="AT";
		end;
		else if age eq 77 then do;
			if count le int(0.9986*max_count) then insttype="AT";
		end;
		else if age eq 78 then do;
			if count le int(0.9988*max_count) then insttype="AT";
		end;
		else if age eq 79 then do;
			if count le int(0.9983*max_count) then insttype="AT";
		end;
		else if age eq 80 then do;
			if count le int(0.9986*max_count) then insttype="AT";
		end;
	run;

	data unique_patid_1;
		set temp (drop=max_count count);
		by age;
		if missing(insttype) then insttype="CR";
	run;
	
	%retrieveObs (interds=unique_patid_2)	
	data unique_patid_2;
		set unique_patid_2;
		if _n_ le (0.005*&internobs) then insttype="CR";
		else insttype="AT";
	run;

	data unique_patid;
		set unique_patid_1 unique_patid_2;
	run;

	proc sql noprint;
		create table subset_2_temp as
		select a.*,b.insttype as new_inst from subset_2 as a, unique_patid as b
				where a.pat_id eq b.pat_id;
	quit;

	data subset_2;
		set subset_2_temp;
		drop insttype;
		rename new_inst=insttype;
	run;

	data subset_3;
		set subset_3;
		insttype="AT";
	run;

	data hospitalization;
		set subset_1 subset_2 subset_3;
	run;
%mend createInstType;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Create length of stay variable*/
%macro createLOSVar;
	data hospitalization;
		set hospitalization;
		acutelos=ddate-admdate;
	run;	
%mend createLOSVar;

%macro createGender;
	data hospitalization;
		length sex $1;
		set hospitalization;
	run;
	
	proc sql noprint;
		create table subset_1 as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
		create table subset_2 as
		select * from hospitalization group by pat_id having count(pat_id) gt 1;
	quit;

	proc sql noprint;
		create table temp as
		select *, count(age) as max_count from subset_1 group by age;
	quit;

	proc sort data=temp out=subset_1;
		by age;
	run;

	data temp;
		set subset_1;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.49295*max_count) then sex="F";
		end;
		else if age in (1:11) then do;
			if count le int(0.4314*max_count) then sex="F";
		end;
		else if age in (12:14) then do;
			if count le int(0.51703*max_count) then sex="F";
		end;
		else if age in (15:17) then do;
			if count le int(0.586*max_count) then sex="F";
		end;
		else if age in (18:19) then do;
			if count le int(0.66*max_count) then sex="F";
		end;
		else if age in (20:22) then do;
			if count le int(0.762*max_count) then sex="F";
		end;
		else if age in (23:25) then do;
			if count le int(0.826*max_count) then sex="F";
		end;
		else if age in (26:37) then do;
			if count le int(0.893*max_count) then sex="F";
		end;
		else if age in (26:37) then do;
			if count le int(0.893*max_count) then sex="F";
		end;
		else if age in (38:40) then do;
			if count le int(0.775*max_count) then sex="F";
		end;
		else if age in (41:43) then do;
			if count le int(0.662*max_count) then sex="F";
		end;
		else if age in (44:53) then do;
			if count le int(0.547*max_count) then sex="F";
		end;
		else if age in (54:71) then do;
			if count le int(0.482*max_count) then sex="F";
		end;
		else if age in (72:79) then do;
			if count le int(0.508*max_count) then sex="F";
		end;
		else if age in (80:85) then do;
			if count le int(0.554*max_count) then sex="F";
		end;
		else if age in (86:90) then do;
			if count le int(0.625*max_count) then sex="F";
		end;
		else if age in (86:90) then do;
			if count le int(0.625*max_count) then sex="F";
		end;
		else if age in (91:100) then do;
			if count le int(0.70*max_count) then sex="F";
		end;
		else sex="F";
	run;

	data temp;
		set temp;
		by age;
		if age in (0:103) and missing(sex) then sex ="M";
	run;
	
	data subset_1;
		set temp (drop =  max_count count);
	run;

	proc sql noprint;
		create table unique_patid_1 as
		select distinct pat_id,age,sex from subset_2 ;
	quit;


	proc sql noprint;
		create table temp as
		select *, count(age) as max_count from unique_patid_1 group by age;
	quit;

	proc sort data=temp out=unique_patid_1;
		by age;
	run;

	data temp;
		set unique_patid_1;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.4285*max_count) then sex="F";
		end;
		else if age in (1:7) then do;
			if count le int(0.4239*max_count) then sex="F";
		end;
		else if age in (8,11,12) then do;
			if count le int(0.5*max_count) then sex="F";
		end;
		else if age in (9,10) then do;
			if count le int(0.4222*max_count) then sex="F";
		end;
		else if age eq 13 then do;
			if count le int(0.61*max_count) then sex="F";
		end;
		else if age in (14:18) then do;
			if count le int(0.6514*max_count) then sex="F";
		end;
		else if age in (19:24) then do;
			if count le int(0.7199*max_count) then sex="F";
		end;
		else if age in (25:32) then do;
			if count le int(0.7913*max_count) then sex="F";
		end;
		else if age in (33:35) then do;
			if count le int(0.7713*max_count) then sex="F";
		end;
		else if age in (36:38) then do;
			if count le int(0.7172*max_count) then sex="F";
		end;
		else if age in (39:42) then do;
			if count le int(0.6314*max_count) then sex="F";
		end;
		else if age in (43:49) then do;
			if count le int(0.5066*max_count) then sex="F";
		end;
		else if age in (50:55) then do;
			if count le int(0.4610*max_count) then sex="F";
		end;
		else if age in (56:71) then do;
			if count le int(0.4346*max_count) then sex="F";
		end;
		else if age in (72:83) then do;
			if count le int(0.4712*max_count) then sex="F";
		end;
		else if age in (83:87) then do;
			if count le int(0.5343*max_count) then sex="F";
		end;
		else if age in (88:93) then do;
			if count le int(0.6097*max_count) then sex="F";
		end;
		else if age in (93:96) then do;
			if count le int(0.6907*max_count) then sex="F";
		end;
		else if age in (96:99) then do;
			if count le int(0.6912*max_count) then sex="F";
		end;
		else if age in (100:101) then do;
			if count le int(0.60*max_count) then sex="F";
		end;
		else sex="F";
	run;

	data temp;
		set temp;
		by age;
		if age in (0:103) and missing(sex) then sex ="M";
	run;
	
	data unique_patid_1;
		set temp (keep =  pat_id sex);
	run;

	data subset_2;
		set subset_2 (drop=sex);
	run;

	proc sql noprint;
		create table temp as
		select a.*,b.sex from subset_2 as a, unique_patid_1 as b
			  where a.pat_id eq b.pat_id;
	quit;

	data subset_2;
		set temp;
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;
%mend createGender;
/*-----------------------------------------------------------------------------------------------------------------------------*/
/* Added by Sean May 11, 2018 */
/*Create the ReferenceData for creating Agreement Report */
%macro createReferenceData(
   ds  = hospitalization
  ,out = ReferenceData 
);

  proc sort data = &ds.(keep =  pat_id sex admdate birthdate where=(pat_id is not missing))
            out  = _temp(drop =  admdate);
    by pat_id admdate;
  run;

  proc sort data=_temp out= &out. nodupkey;
    by pat_id;
  run;

  proc datasets lib=work memtype=data nodetails nolist;
    delete _temp;
  run;

%mend createReferenceData;
/* Added end */

/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Create linkage type (deterministic/probablistic) variable*/
%macro createLinkageType;
	proc sql noprint;
		create table unique_patid_1 as
		select distinct pat_id from hospitalization ;
	quit;

	%retrieveObs (interds=unique_patid_1)
	data unique_patid_1;
		length linkage_type $1;
		set unique_patid_1;
		if  _n_ le int(0.9567*&internobs) then linkage_type="D";
		else linkage_type="P";
	run;

	proc sql noprint;
		create table temp as
		select a.*,b.linkage_type from hospitalization as a, unique_patid_1 as b
			  where a.pat_id eq b.pat_id;
	quit;

	data hospitalization;
		set temp;
	run;
%mend createLinkageType;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to populate dx10code1 variable*/
%macro createDX10code1;
	data hospitalization;
		length dx10code1 $7;
		set hospitalization;
	run;

	proc sql noprint;
		create table subset_1 as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
		create table subset_2 as
		select * from hospitalization group by pat_id having count(pat_id) gt 1;
	quit;

	%createCode1UniquePid (inter_ds=subset_1);
	%createCode1DupPid (inter_ds=subset_2);

	data hospitalization (drop=total_agecount count);
		set subset_1 subset_2;
	run;
%mend createDX10code1;

%macro createCode1UniquePid (inter_ds=);
	proc sql noprint;
		create table temp as
		select * from &inter_ds where sex eq "F";
		create table subset_1a as
		select *,count(age) as total_agecount from temp group by age;
		create table temp as
		select * from &inter_ds where sex eq "M";
		create table subset_1b as
		select *,count(age) as total_agecount from temp group by age;
	quit;

	proc sort data=subset_1a out=temp;
		by age ;
	run;

	data subset_1a;
		set temp;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.7109058035*total_agecount) then dx10code1="Z38000";
			else if count gt int(0.7109058035*total_agecount) and count le int(0.9315355442*total_agecount) then dx10code1="Z38010";
			else if count gt int(0.9315355442*total_agecount) and count le int(0.9966043394*total_agecount) then dx10code1="P071";
			else if count gt int(0.9966043394*total_agecount) and count le int(0.999051861*total_agecount) then dx10code1="N390";
			else if count gt int(0.999051861*total_agecount) and count le int(0.999911801*total_agecount) then dx10code1="J189";
			else if count gt int(0.999911801*total_agecount) and count le int(0.9999338508*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9999338508*total_agecount) and count le int(0.9999559005*total_agecount) then dx10code1="Z515";
			else if count gt int(0.9999559005*total_agecount) and count le int(0.9999779503*total_agecount) then dx10code1="K566";
			else  dx10code1="I500";
		end;
		else if age in (1:2) then do;
			if count le int(0.7098445596*total_agecount) then dx10code1="J189";
			else if count gt int(0.7098445596*total_agecount) and count le int(0.9689119171*total_agecount) then dx10code1="N390";
			else dx10code1="Z540";
		end;
		else if age in (3:6) then do;
			if count le int(0.4246575343*total_agecount) then dx10code1="J189";
			else if count gt int(0.4246575343*total_agecount) and count le int(0.6164383562*total_agecount) then dx10code1="K358";
			else if count gt int(0.6164383562*total_agecount) and count le int(0.7808219178*total_agecount) then dx10code1="Z540";
			else if count gt int(0.7808219178*total_agecount) and count le int(0.9726027397*total_agecount) then dx10code1="N390";
			else if count gt int(0.9726027397*total_agecount) and count le int(0.9863013699*total_agecount) then dx10code1="K566";
			else dx10code1="N179";
		end;
		else if age in (7:13) then do;
			if count le int(0.3448275862*total_agecount) then dx10code1="K358";
			else if count gt int(0.3448275862*total_agecount) and count le int(0.6321839081*total_agecount) then dx10code1="J189";
			else if count gt int(0.6321839081*total_agecount) and count le int(0.7701149425*total_agecount) then dx10code1="Z540";
			else if count gt int(0.7701149425*total_agecount) and count le int(0.9885057471*total_agecount) then dx10code1="N390";
			else dx10code1="K566";
		end;
		else if age in (14:19) then do;
			if count le int(0.1235431235*total_agecount) then dx10code1="K358";
			else if count gt int(0.1235431235*total_agecount) and count le int(0.3181818182*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.3181818182*total_agecount) and count le int(0.4778554779*total_agecount) then dx10code1="O70001";
			else if count gt int(0.4778554779*total_agecount) and count le int(0.6282051282*total_agecount) then dx10code1="O70101";
			else if count gt int(0.6282051282*total_agecount) and count le int(0.7540792541*total_agecount) then dx10code1="O68001";
			else if count gt int(0.7540792541*total_agecount) and count le int(0.8554778555*total_agecount) then dx10code1="O48001";
			else if count gt int(0.8554778555*total_agecount) and count le int(0.9324009324*total_agecount) then dx10code1="O42021";
			else if count gt int(0.9324009324*total_agecount) and count le int(0.9463869464*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9463869464*total_agecount) and count le int(0.9696969697*total_agecount) then dx10code1="O34201";
			else if count gt int(0.9696969697*total_agecount) and count le int(0.9825174825*total_agecount) then dx10code1="J189";
			else if count gt int(0.9825174825*total_agecount) and count le int(0.9941724942*total_agecount) then dx10code1="N390";
			else if count gt int(0.9941724942*total_agecount) and count le int(0.9988344988*total_agecount) then dx10code1="N179";
			else dx10code1="K566";
		end;
		else if age in (20:24) then do;
			if count le int(0.2049117421*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.2049117421*total_agecount) and count le int(0.3599386032*total_agecount) then dx10code1="O70001";
			else if count gt int(0.3599386032*total_agecount) and count le int(0.5111281658*total_agecount) then dx10code1="O70101";
			else if count gt int(0.5111281658*total_agecount) and count le int(0.5694551036*total_agecount) then dx10code1="K358";
			else if count gt int(0.5694551036*total_agecount) and count le int(0.7006907137*total_agecount) then dx10code1="O68001";
			else if count gt int(0.7006907137*total_agecount) and count le int(0.8165771297*total_agecount) then dx10code1="O48001";
			else if count gt int(0.8165771297*total_agecount) and count le int(0.8986953185*total_agecount) then dx10code1="O42021";
			else if count gt int(0.8986953185*total_agecount) and count le int(0.9662317728*total_agecount) then dx10code1="O34201";
			else if count gt int(0.9662317728*total_agecount) and count le int(0.9754412893*total_agecount) then dx10code1="J189";
			else if count gt int(0.9754412893*total_agecount) and count le int(0.9854182655*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9854182655*total_agecount) and count le int(0.9923254029*total_agecount) then dx10code1="N390";
			else if count gt int(0.9923254029*total_agecount) and count le int(0.994627782*total_agecount) then dx10code1="K566";
			else if count gt int(0.994627782*total_agecount) and count le int(0.9976976209*total_agecount) then dx10code1="N179";
			else if count gt int(0.9976976209*total_agecount) and count le int(0.9984650806*total_agecount) then dx10code1="Z515";
			else if count gt int(0.9984650806*total_agecount) and count le int(0.9992325403*total_agecount) then dx10code1="I500";
			else dx10code1="J441";
		end;
		else if age in (25:31) then do;
			if count le int(0.2079613095*total_agecount) then dx10code1="O70101";
			else if count gt int(0.2079613095*total_agecount) and count le int(0.3843005952*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.3843005952*total_agecount) and count le int(0.5275297619*total_agecount) then dx10code1="O68001";
			else if count gt int(0.5275297619*total_agecount) and count le int(0.6577380952*total_agecount) then dx10code1="O70001";
			else if count gt int(0.6577380952*total_agecount) and count le int(0.7697172619*total_agecount) then dx10code1="O48001";
			else if count gt int(0.7697172619*total_agecount) and count le int(0.8686755952*total_agecount) then dx10code1="O34201";
			else if count gt int(0.8686755952*total_agecount) and count le int(0.9575892857*total_agecount) then dx10code1="O42021";
			else if count gt int(0.9575892857*total_agecount) and count le int(0.9817708333*total_agecount) then dx10code1="K358";
			else if count gt int(0.9817708333*total_agecount) and count le int(0.990327381*total_agecount) then  dx10code1="Z540";
			else if count gt int(0.990327381*total_agecount) and count le int(0.9947916667*total_agecount) then dx10code1="J189";
			else if count gt int(0.9947916667*total_agecount) and count le int(0.9973958333*total_agecount) then dx10code1="N390";
			else if count gt int(0.9973958333*total_agecount) and count le int(0.998139881*total_agecount) then  dx10code1="K566";
			else if count gt int(0.998139881*total_agecount) and count le int(0.9988839286*total_agecount) then dx10code1="N179";
			else if count gt int(0.9988839286*total_agecount) and count le int(0.9992559524*total_agecount) then dx10code1="I500";
			else if count gt int(0.9992559524*total_agecount) and count le int(0.9996279762*total_agecount) then  dx10code1="J441";
			else  dx10code1="Z515";
		end;
		else if age in (32:52) then do;
			if count le int(0.251659292*total_agecount) then dx10code1="O34201";
			else if count gt int(0.251659292*total_agecount) and count le int(0.4681969027*total_agecount) then dx10code1="O70101";
			else if count gt int(0.4681969027*total_agecount) and count le int(0.594579646*total_agecount) then dx10code1="O68001";
			else if count gt int(0.594579646*total_agecount) and count le int(0.7165376106*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.7165376106*total_agecount) and count le int(0.814159292*total_agecount) then dx10code1="O70001";
			else if count gt int(0.814159292*total_agecount) and count le int(0.8979535398*total_agecount) then dx10code1="O48001";
			else if count gt int(0.8979535398*total_agecount) and count le int(0.9651548673*total_agecount) then dx10code1="O42021";
			else if count gt int(0.9651548673*total_agecount) and count le int(0.9809181416*total_agecount) then dx10code1="K358";
			else if count gt int(0.9809181416*total_agecount) and count le int(0.9886615044*total_agecount) then  dx10code1="Z540";
			else if count gt int(0.9886615044*total_agecount) and count le int(0.9936393805*total_agecount) then dx10code1="J189";
			else if count gt int(0.9936393805*total_agecount) and count le int(0.9947455752*total_agecount) then dx10code1="K566";
			else if count gt int(0.9947455752*total_agecount) and count le int(0.9961283186*total_agecount) then  dx10code1="N390";
			else if count gt int(0.9961283186*total_agecount) and count le int(0.9969579646*total_agecount) then  dx10code1="N179";
			else if count gt int(0.9969579646*total_agecount) and count le int(0.997511062*total_agecount) then dx10code1="I214";
			else if count gt int(0.997511062*total_agecount) and count le int(0.998340708*total_agecount) then dx10code1="J441";
			else if count gt int(0.998340708*total_agecount) and count le int(0.9986172566*total_agecount) then  dx10code1="I2510";
			else if count gt int(0.9986172566*total_agecount) and count le int(0.9988938053*total_agecount) then dx10code1="I500";
			else if count gt int(0.9988938053*total_agecount) and count le int(0.999170354*total_agecount) then dx10code1="M179";
			else if count gt int(0.999170354*total_agecount) and count le int(0.9997234513*total_agecount) then dx10code1="Z515";
			else dx10code1="P071";
		end;
		else if age in (53:79) then do;
			if count le int(0.2567409144*total_agecount) then dx10code1="M179";
			else if count gt int(0.2567409144*total_agecount) and count le int(0.3036342321*total_agecount) then dx10code1="I2510";
			else if count gt int(0.3036342321*total_agecount) and count le int(0.4407971864*total_agecount) then dx10code1="M170";
			else if count gt int(0.4407971864*total_agecount) and count le int(0.5627198124*total_agecount) then dx10code1="M169";
			else if count gt int(0.5627198124*total_agecount) and count le int(0.6178194607*total_agecount) then dx10code1="I214";
			else if count gt int(0.6178194607*total_agecount) and count le int(0.7362250879*total_agecount) then dx10code1="Z540";
			else if count gt int(0.7362250879*total_agecount) and count le int(0.776084408*total_agecount) then dx10code1="J441";
			else if count gt int(0.776084408*total_agecount) and count le int(0.8077373974*total_agecount) then dx10code1="J189";
			else if count gt int(0.8077373974*total_agecount) and count le int(0.8499413834*total_agecount) then  dx10code1="I500";
			else if count gt int(0.8499413834*total_agecount) and count le int(0.8886283705*total_agecount) then dx10code1="K566";
			else if count gt int(0.8886283705*total_agecount) and count le int(0.9273153576*total_agecount) then dx10code1="Z515";
			else if count gt int(0.9273153576*total_agecount) and count le int(0.9624853458*total_agecount) then  dx10code1="N390";
			else if count gt int(0.9624853458*total_agecount) and count le int(0.978898007*total_agecount) then dx10code1="N179";
			else dx10code1="K358";
		end;
		else if age in (80:89) then do;
			if count le int(0.1577287066*total_agecount) then dx10code1="I500";
			else if count gt int(0.1577287066*total_agecount) and count le int(0.2712933754*total_agecount) then dx10code1="J189";
			else if count gt int(0.2712933754*total_agecount) and count le int(0.3922187171*total_agecount) then dx10code1="Z515";
			else if count gt int(0.3922187171*total_agecount) and count le int(0.523659306*total_agecount) then dx10code1="N390";
			else if count gt int(0.523659306*total_agecount) and count le int(0.6077812829*total_agecount) then dx10code1="J440";
			else if count gt int(0.6077812829*total_agecount) and count le int(0.6792849632*total_agecount) then dx10code1="I214";
			else if count gt int(0.6792849632*total_agecount) and count le int(0.7402733964*total_agecount) then dx10code1="J441";
			else if count gt int(0.7402733964*total_agecount) and count le int(0.8128286015*total_agecount) then dx10code1="M179";
			else if count gt int(0.8128286015*total_agecount) and count le int(0.8559411146*total_agecount) then  dx10code1="N179";
			else if count gt int(0.8559411146*total_agecount) and count le int(0.9043112513*total_agecount) then dx10code1="M169";
			else if count gt int(0.9043112513*total_agecount) and count le int(0.9369085174*total_agecount) then dx10code1="K566";
			else if count gt int(0.9369085174*total_agecount) and count le int(0.9716088328*total_agecount) then  dx10code1="M170";
			else if count gt int(0.9716088328*total_agecount) and count le int(0.9884332282*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9884332282*total_agecount) and count le int(0.9978969506*total_agecount) then dx10code1="Z540";
			else dx10code1="K358";
		end;
	else if age in (90:95) then do;
			if count le int(0.216374269*total_agecount) then dx10code1="I500";
			else if count gt int(0.216374269*total_agecount) and count le int(0.4074074074*total_agecount) then dx10code1="J189";
			else if count gt int(0.4074074074*total_agecount) and count le int(0.5750487329*total_agecount) then dx10code1="Z515";
			else if count gt int(0.5750487329*total_agecount) and count le int(0.7290448343*total_agecount) then dx10code1="N390";
			else if count gt int(0.7290448343*total_agecount) and count le int(0.7933723197*total_agecount) then dx10code1="J440";
			else if count gt int(0.7933723197*total_agecount) and count le int(0.873294347*total_agecount) then dx10code1="I214";
			else if count gt int(0.873294347*total_agecount) and count le int(0.9122807018*total_agecount) then dx10code1="N179";
			else if count gt int(0.9122807018*total_agecount) and count le int(0.9473684211*total_agecount) then dx10code1="K566";
			else if count gt int(0.9473684211*total_agecount) and count le int(0.9688109162*total_agecount) then  dx10code1="J441";
			else if count gt int(0.9688109162*total_agecount) and count le int(0.9824561404*total_agecount) then dx10code1="M169";
			else if count gt int(0.9824561404*total_agecount) and count le int(0.9883040936*total_agecount) then dx10code1="M179";
			else if count gt int(0.9883040936*total_agecount) and count le int(0.992202729*total_agecount) then  dx10code1="Z540";
			else if count gt int(0.992202729*total_agecount) and count le int(0.9941520468*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9941520468*total_agecount) and count le int(0.9980506823*total_agecount) then dx10code1="M170";
			else dx10code1="K358";
		end;
		else  do;
			if count le int(0.2962962963*total_agecount) then dx10code1="Z515";
			else if count gt int(0.2962962963*total_agecount) and count le int(0.4814814815*total_agecount) then dx10code1="J189";
			else if count gt int(0.4814814815*total_agecount) and count le int(0.6049382716*total_agecount) then dx10code1="I500";
			else if count gt int(0.6049382716*total_agecount) and count le int(0.7777777778*total_agecount) then dx10code1="N390";
			else if count gt int(0.7777777778*total_agecount) and count le int(0.8148148148*total_agecount) then dx10code1="J440";
			else if count gt int(0.8148148148*total_agecount) and count le int(0.8765432099*total_agecount) then dx10code1="I214";
			else if count gt int(0.8765432099*total_agecount) and count le int(0.9259259259*total_agecount) then dx10code1="N179";
			else if count gt int(0.9259259259*total_agecount) and count le int(0.962962963*total_agecount) then dx10code1="K566";
			else if count gt int(0.962962963*total_agecount) and count le int(0.975308642*total_agecount) then  dx10code1="Z540";
			else if count gt int(0.975308642*total_agecount) and count le int(0.987654321*total_agecount) then dx10code1="J441";
			else dx10code1="M169";
		end;
	run;

	proc sort data=subset_1b out=temp;
		by age ;
	run;

	data subset_1b;
		set temp;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.7120440468*total_agecount) then dx10code1="Z38000";
			else if count gt int(0.7120440468*total_agecount) and count le int(0.9454462033*total_agecount) then dx10code1="Z38010";
			else if count gt int(0.9454462033*total_agecount) and count le int(0.996673549*total_agecount) then dx10code1="P071";
			else if count gt int(0.996673549*total_agecount) and count le int(0.9983941271*total_agecount) then dx10code1="N390";
			else if count gt int(0.9983941271*total_agecount) and count le int(0.9996788254*total_agecount) then dx10code1="J189";
			else if count gt int(0.9996788254*total_agecount) and count le int(0.9999311769*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9999311769*total_agecount) and count le int(0.999977059*total_agecount) then dx10code1="Z515";
			else dx10code1="K566";
		end;
		else if age in (1:2) then do;
			if count le int(0.8438818565*total_agecount) then dx10code1="J189";
			else if count gt int(0.8438818565*total_agecount) and count le int(0.9282700422*total_agecount) then dx10code1="N390";
			else if count gt int(0.9282700422*total_agecount) and count le int(0.9957805907*total_agecount) then dx10code1="Z540";
			else  dx10code1="K566";
		end;
		else if age in (3:6) then do;
			if count le int(0.3370786517*total_agecount) then dx10code1="J189";
			else if count gt int(0.3370786517*total_agecount) and count le int(0.7191011236*total_agecount) then dx10code1="K358";
			else if count gt int(0.7191011236*total_agecount) and count le int(0.9775280899*total_agecount) then dx10code1="Z540";
			else  dx10code1="K566";
		end;
		else if age in (7:13) then do;
			if count le int(0.6774193548*total_agecount) then dx10code1="K358";
			else if count gt int(0.6774193548*total_agecount) and count le int(0.8172043011*total_agecount) then dx10code1="J189";
			else if count gt int(0.8172043011*total_agecount) and count le int(0.9462365591*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9462365591*total_agecount) and count le int(0.9677419355*total_agecount) then dx10code1="N390";
			else if count gt int(0.9677419355*total_agecount) and count le int(0.9784946237*total_agecount) then dx10code1="J441";
			else if count gt int(0.9784946237*total_agecount) and count le int(0.9892473118*total_agecount) then dx10code1="N179";
			else  dx10code1="Z515";
		end;
		else if age in (14:19) then do;
			if count le int(0.8133333333*total_agecount) then dx10code1="K358";
			else if count gt int(0.8133333333*total_agecount) and count le int(0.88*total_agecount) then dx10code1="Z540";
			else if count gt int(0.88*total_agecount) and count le int(0.9333333333*total_agecount) then dx10code1="J189";
			else if count gt int(0.9333333333*total_agecount) and count le int(0.96*total_agecount) then dx10code1="N179";
			else if count gt int(0.96*total_agecount) and count le int(0.9866666667*total_agecount) then dx10code1="K566";
			else if count gt int(0.9866666667*total_agecount) and count le int(0.9933333333*total_agecount) then dx10code1="I214";
			else dx10code1="I2510";
		end;
		else if age in (20:24) then do;
			if count le int(0.7578125*total_agecount) then dx10code1="K358";
			else if count gt int(0.7578125*total_agecount) and count le int(0.859375*total_agecount) then dx10code1="J189";
			else if count gt int(0.859375*total_agecount) and count le int(0.9375*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9375*total_agecount) and count le int(0.9453125*total_agecount) then dx10code1="N390";
			else if count gt int(0.9453125*total_agecount) and count le int(0.9765625*total_agecount) then dx10code1="K566";
			else if count gt int(0.9765625*total_agecount) and count le int(0.9921875*total_agecount) then dx10code1="N179";
			else dx10code1="Z515";
		end;
		else if age in (25:31) then do;
			if  count le int(0.75*total_agecount) then dx10code1="K358";
			else if count gt int(0.75*total_agecount) and count le int(0.8839285714*total_agecount) then  dx10code1="Z540";
			else if count gt int(0.8839285714*total_agecount) and count le int(0.9196428571*total_agecount) then dx10code1="J189";
			else if count gt int(0.9196428571*total_agecount) and count le int(0.9375*total_agecount) then dx10code1="N390";
			else if count gt int(0.9375*total_agecount) and count le int(0.9732142857*total_agecount) then  dx10code1="K566";
			else if count gt int(0.9732142857*total_agecount) and count le int(0.9910714286*total_agecount) then dx10code1="N179";
			else  dx10code1="I500";
		end;
		else if age in (32:52) then do;
			if count le int(0.4919354839*total_agecount) then dx10code1="K358";
			else if count gt int(0.4919354839*total_agecount) and count le int(0.6451612903*total_agecount) then dx10code1="Z540";
			else if count gt int(0.6451612903*total_agecount) and count le int(0.7983870968*total_agecount) then dx10code1="J189";
			else if count gt int(0.7983870968*total_agecount) and count le int(0.8548387097*total_agecount) then dx10code1="K566";
			else if count gt int(0.8548387097*total_agecount) and count le int(0.8790322581*total_agecount) then dx10code1="N390";
			else if count gt int(0.8790322581*total_agecount) and count le int(0.9112903226*total_agecount) then dx10code1="N179";
			else if count gt int(0.9112903226*total_agecount) and count le int(0.9435483871*total_agecount) then dx10code1="I214";
			else if count gt int(0.9435483871*total_agecount) and count le int(0.9516129032*total_agecount) then dx10code1="J441";
			else if count gt int(0.9516129032*total_agecount) and count le int(0.9596774194*total_agecount) then  dx10code1="I2510";
			else if count gt int(0.9596774194*total_agecount) and count le int(0.9677419355*total_agecount) then dx10code1="I500";
			else if count gt int(0.9677419355*total_agecount) and count le int(0.9838709677*total_agecount) then dx10code1="M169";
			else if count gt int(0.9838709677*total_agecount) and count le int(0.9919354839*total_agecount) then  dx10code1="M179";
			else dx10code1="M170";
		end;
		else if age in (53:79) then do;
			if count le int(0.1430119177*total_agecount) then dx10code1="M179";
			else if count gt int(0.1430119177*total_agecount) and count le int(0.3206933911*total_agecount) then dx10code1="I2510";
			else if count gt int(0.3206933911*total_agecount) and count le int(0.4019501625*total_agecount) then dx10code1="M170";
			else if count gt int(0.4019501625*total_agecount) and count le int(0.4962080173*total_agecount) then dx10code1="M169";
			else if count gt int(0.4962080173*total_agecount) and count le int(0.5850487541*total_agecount) then dx10code1="I214";
			else if count gt int(0.5850487541*total_agecount) and count le int(0.6446370531*total_agecount) then dx10code1="Z540";
			else if count gt int(0.6446370531*total_agecount) and count le int(0.6977248104*total_agecount) then dx10code1="J441";
			else if count gt int(0.6977248104*total_agecount) and count le int(0.7551462622*total_agecount) then dx10code1="J189";
			else if count gt int(0.7551462622*total_agecount) and count le int(0.8114842904*total_agecount) then  dx10code1="I500";
			else if count gt int(0.8114842904*total_agecount) and count le int(0.8548212351*total_agecount) then dx10code1="J440";
			else if count gt int(0.8548212351*total_agecount) and count le int(0.8905742145*total_agecount) then dx10code1="K566";
			else if count gt int(0.8905742145*total_agecount) and count le int(0.9263271939*total_agecount) then  dx10code1="Z515";
			else if count gt int(0.9263271939*total_agecount) and count le int(0.9512459372*total_agecount) then dx10code1="N390";
			else if count gt int(0.9512459372*total_agecount) and count le int(0.9848320693*total_agecount) then dx10code1="N179";
			else dx10code1="K358";
		end;
		else if age in (80:89) then do;
			if count le int(0.1715817694*total_agecount) then dx10code1="I500";
			else if count gt int(0.1715817694*total_agecount) and count le int(0.3257372654*total_agecount) then dx10code1="J189";
			else if count gt int(0.3257372654*total_agecount) and count le int(0.4463806971*total_agecount) then dx10code1="Z515";
			else if count gt int(0.4463806971*total_agecount) and count le int(0.5335120643*total_agecount) then dx10code1="N390";
			else if count gt int(0.5335120643*total_agecount) and count le int(0.6179624665*total_agecount) then dx10code1="J440";
			else if count gt int(0.6179624665*total_agecount) and count le int(0.6890080429*total_agecount) then dx10code1="I214";
			else if count gt int(0.6890080429*total_agecount) and count le int(0.7667560322*total_agecount) then dx10code1="J441";
			else if count gt int(0.7667560322*total_agecount) and count le int(0.8136729223*total_agecount) then dx10code1="M179";
			else if count gt int(0.8136729223*total_agecount) and count le int(0.855227882*total_agecount) then  dx10code1="N179";
			else if count gt int(0.855227882*total_agecount) and count le int(0.8887399464*total_agecount) then dx10code1="M169";
			else if count gt int(0.8887399464*total_agecount) and count le int(0.927613941*total_agecount) then dx10code1="K566";
			else if count gt int(0.927613941*total_agecount) and count le int(0.9477211796*total_agecount) then  dx10code1="M170";
			else if count gt int(0.9477211796*total_agecount) and count le int(0.9825737265*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9825737265*total_agecount) and count le int(0.9986595174*total_agecount) then dx10code1="Z540";
			else dx10code1="K358";
		end;
		else if age in (90:95) then do;
			if count le int(0.2023346304*total_agecount) then dx10code1="I500";
			else if count gt int(0.2023346304*total_agecount) and count le int(0.3813229572*total_agecount) then dx10code1="J189";
			else if count gt int(0.3813229572*total_agecount) and count le int(0.5486381323*total_agecount) then dx10code1="Z515";
			else if count gt int(0.5486381323*total_agecount) and count le int(0.6420233463*total_agecount) then dx10code1="N390";
			else if count gt int(0.6420233463*total_agecount) and count le int(0.7704280156*total_agecount) then dx10code1="J440";
			else if count gt int(0.7704280156*total_agecount) and count le int(0.8326848249*total_agecount) then dx10code1="I214";
			else if count gt int(0.8326848249*total_agecount) and count le int(0.9027237354*total_agecount) then dx10code1="N179";
			else if count gt int(0.9027237354*total_agecount) and count le int(0.9455252918*total_agecount) then dx10code1="K566";
			else if count gt int(0.9455252918*total_agecount) and count le int(0.9805447471*total_agecount) then  dx10code1="J441";
			else if count gt int(0.9805447471*total_agecount) and count le int(0.9844357977*total_agecount) then dx10code1="M169";
			else if count gt int(0.9844357977*total_agecount) and count le int(0.9922178988*total_agecount) then dx10code1="M179";
			else if count gt int(0.9922178988*total_agecount) and count le int(0.9961089494*total_agecount) then  dx10code1="Z540";
			else dx10code1="I2510";
		end;
		else  do;
			if count le int(0.15*total_agecount) then dx10code1="Z515";
			else if count gt int(0.15*total_agecount) and count le int(0.375*total_agecount) then dx10code1="J189";
			else if count gt int(0.375*total_agecount) and count le int(0.65*total_agecount) then dx10code1="I500";
			else if count gt int(0.65*total_agecount) and count le int(0.80*total_agecount) then dx10code1="N390";
			else if count gt int(0.80*total_agecount) and count le int(0.925*total_agecount) then dx10code1="J440";
			else if count gt int(0.925*total_agecount) and count le int(0.975*total_agecount) then dx10code1="I214";
			else dx10code1="Z540";
		end;
	run;

	data subset_1;
		set subset_1a subset_1b;
	run;
%mend createCode1UniquePid;

%macro createCode1DupPid (inter_ds=);
	proc sort data=&inter_ds;
		by age pat_id admdate;
	run;

	data subset_2a subset_2b;
		set subset_2;
		by age pat_id admdate;
		if  first.pat_id and first.admdate then output subset_2a;
		else output subset_2b;
	run;

	proc sql noprint;
		create table temp as
		select * from subset_2a where sex eq "F";
		create table subset_2a_1 as
		select *,count(age) as total_agecount from temp group by age;
		create table temp as
		select * from subset_2a where sex eq "M";
		create table subset_2a_2 as
		select *,count(age) as total_agecount from temp group by age;

		create table temp as
		select * from subset_2b where sex eq "F";
		create table subset_2b_1 as
		select *,count(age) as total_agecount from temp group by age;
		create table temp as
		select * from subset_2b where sex eq "M";
		create table subset_2b_2 as
		select *,count(age) as total_agecount from temp group by age;
	quit;

	proc sort data=subset_2a_1 out=temp;
		by age ;
	run;

	data subset_2a_1;
		set temp;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.5778909527*total_agecount) then dx10code1="Z38000";
			else if count gt int(0.5778909527*total_agecount) and count le int(0.8361294188*total_agecount) then dx10code1="P071";
			else if count gt int(0.8361294188*total_agecount) and count le int(0.9919113242*total_agecount) then dx10code1="Z38010";
			else if count gt int(0.9919113242*total_agecount) and count le int(0.9940083883*total_agecount) then dx10code1="J189";
			else if count gt int(0.9940083883*total_agecount) and count le int(0.9985020971*total_agecount) then dx10code1="N390";
			else if count gt int(0.9985020971*total_agecount) and count le int(0.9991012582*total_agecount) then dx10code1="I500";
			else if count gt int(0.9991012582*total_agecount) and count le int(0.9997004194*total_agecount) then dx10code1="K566";
			else dx10code1="Z540";
		end;
		else if age in (1:2) then do;
			if count le int(0.7391304348*total_agecount) then dx10code1="J189";
			else if count gt int(0.7391304348*total_agecount) and count le int(0.9130434783*total_agecount) then dx10code1="N390";
			else if count gt int(0.9130434783*total_agecount) and count le int(0.9565217391*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9565217391*total_agecount) and count le int(0.9782608696*total_agecount) then dx10code1="I500";
			else dx10code1="Z515";
		end;
		else if age in (3:6) then do;
			if count le int(0.5454545455*total_agecount) then dx10code1="J189";
			else if count gt int(0.5454545455*total_agecount) and count le int(0.7272727273*total_agecount) then dx10code1="N390";
			else if count gt int(0.7272727273*total_agecount) and count le int(0.9090909091*total_agecount) then dx10code1="Z540";
			else dx10code1="I500";
		end;
		else if age in (7:13) then do;
			if count le int(0.5714285714*total_agecount) then dx10code1="J189";
			else if count gt int(0.5714285714*total_agecount) and count le int(0.7142857143*total_agecount) then dx10code1="K358";
			else if count gt int(0.7142857143*total_agecount) and count le int(0.8571428571*total_agecount) then dx10code1="K566";
			else dx10code1="Z540";
		end;
		else if age in (14:19) then do;
			if count le int(0.1481481482*total_agecount) then dx10code1="K358";
			else if count gt int(0.1481481482*total_agecount) and count le int(0.3333333333*total_agecount) then dx10code1="O68001";
			else if count gt int(0.3333333333*total_agecount) and count le int(0.5185185185*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.5185185185*total_agecount) and count le int(0.6851851852*total_agecount) then dx10code1="O70001";
			else if count gt int(0.6851851852*total_agecount) and count le int(0.7777777778*total_agecount) then dx10code1="O70101";
			else if count gt int(0.7777777778*total_agecount) and count le int(0.7962962963*total_agecount) then dx10code1="J189";
			else if count gt int(0.7962962963*total_agecount) and count le int(0.8333333333*total_agecount) then dx10code1="K566";
			else if count gt int(0.8333333333*total_agecount) and count le int(0.8888888889*total_agecount) then dx10code1="O42021";
			else if count gt int(0.8888888889*total_agecount) and count le int(0.9074074074*total_agecount) then dx10code1="I500";
			else if count gt int(0.9074074074*total_agecount) and count le int(0.9444444444*total_agecount) then dx10code1="N390";
			else if count gt int(0.9444444444*total_agecount) and count le int(0.9814814815*total_agecount) then dx10code1="O48001";
			else dx10code1="O34201";
		end;
		else if age in (20:24) then do;
			if count le int(0.1785714286*total_agecount) then dx10code1="O68001";
			else if count gt int(0.1785714286*total_agecount) and count le int(0.2678571429*total_agecount) then dx10code1="J189";
			else if count gt int(0.2678571429*total_agecount) and count le int(0.4107142857*total_agecount) then dx10code1="O70101";
			else if count gt int(0.4107142857*total_agecount) and count le int(0.4821428571*total_agecount) then dx10code1="K358";
			else if count gt int(0.4821428571*total_agecount) and count le int(0.6071428571*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.6071428571*total_agecount) and count le int(0.7142857143*total_agecount) then dx10code1="O48001";
			else if count gt int(0.7142857143*total_agecount) and count le int(0.75*total_agecount) then dx10code1="N390";
			else if count gt int(0.75*total_agecount) and count le int(0.8392857143*total_agecount) then dx10code1="O34201";
			else if count gt int(0.8392857143*total_agecount) and count le int(0.875*total_agecount) then dx10code1="K566";
			else if count gt int(0.875*total_agecount) and count le int(0.9285714286*total_agecount) then dx10code1="O42021";
			else if count gt int(0.9285714286*total_agecount) and count le int(0.9821428571*total_agecount) then dx10code1="O70001";
			else dx10code1="Z540";
		end;
		else if age in (25:31) then do;
			if count le int(0.1506849315*total_agecount) then dx10code1="O48001";
			else if count gt int(0.1506849315*total_agecount) and count le int(0.2876712329*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.2876712329*total_agecount) and count le int(0.3698630137*total_agecount) then dx10code1="K358";
			else if count gt int(0.3698630137*total_agecount) and count le int(0.4520547945*total_agecount) then dx10code1="K566";
			else if count gt int(0.4520547945*total_agecount) and count le int(0.5479452055*total_agecount) then dx10code1="O34201";
			else if count gt int(0.5479452055*total_agecount) and count le int(0.6438356164*total_agecount) then dx10code1="O70101";
			else if count gt int(0.6438356164*total_agecount) and count le int(0.698630137*total_agecount) then dx10code1="N390";
			else if count gt int(0.698630137*total_agecount) and count le int(0.7808219178*total_agecount) then dx10code1="O68001";
			else if count gt int(0.7808219178*total_agecount) and count le int(0.8493150685*total_agecount) then dx10code1="O42021";
			else if count gt int(0.8493150685*total_agecount) and count le int(0.9178082192*total_agecount) then dx10code1="O70001";
			else if count gt int(0.9178082192*total_agecount) and count le int(0.9726027397*total_agecount) then dx10code1="J189";
			else if count gt int(0.9726027397*total_agecount) and count le int(0.9863013699*total_agecount) then dx10code1="N179";
			else dx10code1="Z540";
		end;
		else if age in (32:52) then do;
			if count le int(0.2459016393*total_agecount) then dx10code1="O34201";
			else if count gt int(0.2459016393*total_agecount) and count le int(0.3770491803*total_agecount) then dx10code1="O68001";
			else if count gt int(0.3770491803*total_agecount) and count le int(0.4590163934*total_agecount) then dx10code1="K358";
			else if count gt int(0.4590163934*total_agecount) and count le int(0.5655737705*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.5655737705*total_agecount) and count le int(0.6639344262*total_agecount) then dx10code1="O70101";
			else if count gt int(0.6639344262*total_agecount) and count le int(0.7213114754*total_agecount) then dx10code1="J189";
			else if count gt int(0.7213114754*total_agecount) and count le int(0.7704918033*total_agecount) then dx10code1="Z540";
			else if count gt int(0.7704918033*total_agecount) and count le int(0.8032786885*total_agecount) then dx10code1="K566";
			else if count gt int(0.8032786885*total_agecount) and count le int(0.8606557377*total_agecount) then dx10code1="O48001";
			else if count gt int(0.8606557377*total_agecount) and count le int(0.868852459*total_agecount) then dx10code1="I500";
			else if count gt int(0.868852459*total_agecount) and count le int(0.9098360656*total_agecount) then dx10code1="N390";
			else if count gt int(0.9098360656*total_agecount) and count le int(0.9426229508*total_agecount) then dx10code1="O42021";
			else if count gt int(0.9426229508*total_agecount) and count le int(0.9754098361*total_agecount) then dx10code1="O70001";
			else if count gt int(0.9754098361*total_agecount) and count le int(0.9836065574*total_agecount) then dx10code1="I214";
			else if count gt int(0.9836065574*total_agecount) and count le int(0.9918032787*total_agecount) then dx10code1="I2510";
			else dx10code1="J440";
		end;
		else if age in (53:79) then do;
			if count le int(0.1397515528*total_agecount) then dx10code1="I214";
			else if count gt int(0.1397515528*total_agecount) and count le int(0.2173913044*total_agecount) then dx10code1="I500";
			else if count gt int(0.2173913044*total_agecount) and count le int(0.3416149068*total_agecount) then dx10code1="J441";
			else if count gt int(0.3416149068*total_agecount) and count le int(0.3850931677*total_agecount) then dx10code1="I2510";
			else if count gt int(0.3850931677*total_agecount) and count le int(0.4534161491*total_agecount) then dx10code1="J440";
			else if count gt int(0.4534161491*total_agecount) and count le int(0.549689441*total_agecount) then dx10code1="J189";
			else if count gt int(0.549689441*total_agecount) and count le int(0.6428571429*total_agecount) then dx10code1="M179";
			else if count gt int(0.6428571429*total_agecount) and count le int(0.7049689441*total_agecount) then dx10code1="N179";
			else if count gt int(0.7049689441*total_agecount) and count le int(0.7577639752*total_agecount) then dx10code1="K566";
			else if count gt int(0.7577639752*total_agecount) and count le int(0.8074534162*total_agecount) then dx10code1="N390";
			else if count gt int(0.8074534162*total_agecount) and count le int(0.8416149068*total_agecount) then dx10code1="Z540";
			else if count gt int(0.8416149068*total_agecount) and count le int(0.8944099379*total_agecount) then dx10code1="M169";
			else if count gt int(0.8944099379*total_agecount) and count le int(0.950310559*total_agecount) then dx10code1="M170";
			else if count gt int(0.950310559*total_agecount) and count le int(0.9906832298*total_agecount) then dx10code1="Z515";
			else dx10code1="K358";
		end;
		else if age in (80:89) then do;
			if count le int(0.2342192691*total_agecount) then dx10code1="I500";
			else if count gt int(0.2342192691*total_agecount) and count le int(0.3787375415*total_agecount) then dx10code1="I214";
			else if count gt int(0.3787375415*total_agecount) and count le int(0.5265780731*total_agecount) then dx10code1="N390";
			else if count gt int(0.5265780731*total_agecount) and count le int(0.6511627907*total_agecount) then dx10code1="J189";
			else if count gt int(0.6511627907*total_agecount) and count le int(0.7325581395*total_agecount) then dx10code1="J440";
			else if count gt int(0.7325581395*total_agecount) and count le int(0.8073089701*total_agecount) then dx10code1="J441";
			else if count gt int(0.8073089701*total_agecount) and count le int(0.8554817276*total_agecount) then dx10code1="N179";
			else if count gt int(0.8554817276*total_agecount) and count le int(0.8970099668*total_agecount) then dx10code1="Z515";
			else if count gt int(0.8970099668*total_agecount) and count le int(0.9219269103*total_agecount) then dx10code1="K566";
			else if count gt int(0.9219269103*total_agecount) and count le int(0.9352159468*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9352159468*total_agecount) and count le int(0.9651162791*total_agecount) then dx10code1="M169";
			else if count gt int(0.9651162791*total_agecount) and count le int(0.9750830565*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9750830565*total_agecount) and count le int(0.9900332226*total_agecount) then dx10code1="M179";
			else dx10code1="M170";
		end;
		else if age in (90:95) then do;
			if count le int(0.288973384*total_agecount) then dx10code1="I500";
			else if count gt int(0.288973384*total_agecount) and count le int(0.4904942966*total_agecount) then dx10code1="N390";
			else if count gt int(0.4904942966*total_agecount) and count le int(0.6539923954*total_agecount) then dx10code1="J189";
			else if count gt int(0.6539923954*total_agecount) and count le int(0.7452471483*total_agecount) then dx10code1="I214";
			else if count gt int(0.7452471483*total_agecount) and count le int(0.8022813688*total_agecount) then dx10code1="J440";
			else if count gt int(0.8022813688*total_agecount) and count le int(0.8593155894*total_agecount) then dx10code1="J441";
			else if count gt int(0.8593155894*total_agecount) and count le int(0.9163498099*total_agecount) then dx10code1="N179";
			else if count gt int(0.9163498099*total_agecount) and count le int(0.9543726236*total_agecount) then dx10code1="Z515";
			else if count gt int(0.9543726236*total_agecount) and count le int(0.9771863118*total_agecount) then dx10code1="K566";
			else if count gt int(0.9771863118*total_agecount) and count le int(0.9847908745*total_agecount) then dx10code1="M169";
			else if count gt int(0.9847908745*total_agecount) and count le int(0.9885931559*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9885931559*total_agecount) and count le int(0.9923954373*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9923954373*total_agecount) and count le int(0.9961977186*total_agecount) then dx10code1="M170";
			else dx10code1="M179";
		end;
		else  do;
			if count le int(0.2888888889*total_agecount) then dx10code1="I500";
			else if count gt int(0.2888888889*total_agecount) and count le int(0.4888888889*total_agecount) then dx10code1="J189";
			else if count gt int(0.4888888889*total_agecount) and count le int(0.5777777778*total_agecount) then dx10code1="N390";
			else if count gt int(0.5777777778*total_agecount) and count le int(0.6888888889*total_agecount) then dx10code1="J441";
			else if count gt int(0.6888888889*total_agecount) and count le int(0.80*total_agecount) then dx10code1="I214";
			else if count gt int(0.80*total_agecount) and count le int(0.8888888889*total_agecount) then dx10code1="J440";
			else if count gt int(0.8888888889*total_agecount) and count le int(0.9555555556*total_agecount) then dx10code1="N179";
			else if count gt int(0.9555555556*total_agecount) and count le int(0.9777777778*total_agecount) then dx10code1="K566";
			else dx10code1="Z540";
		end;
	run;

	proc sort data=subset_2a_2 out=temp;
		by age ;
	run;

	data subset_2a_2;
		set temp;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.6025124437*total_agecount) then dx10code1="Z38000";
			else if count gt int(0.6025124437*total_agecount) and count le int(0.8310026073*total_agecount) then dx10code1="P071";
			else if count gt int(0.8310026073*total_agecount) and count le int(0.9943114482*total_agecount) then dx10code1="Z38010";
			else if count gt int(0.9943114482*total_agecount) and count le int(0.9981038161*total_agecount) then dx10code1="J189";
			else dx10code1="N390";
		end;
		else if age in (1:2) then do;
			if count le int(0.8913043478*total_agecount) then dx10code1="J189";
			else if count gt int(0.8913043478*total_agecount) and count le int(0.9130434783*total_agecount) then dx10code1="N390";
			else if count gt int(0.9130434783*total_agecount) and count le int(0.9347826087*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9347826087*total_agecount) and count le int(0.9565217391*total_agecount) then dx10code1="I500";
			else if count gt int(0.9565217391*total_agecount) and count le int(0.9782608696*total_agecount) then dx10code1="K358";
			else dx10code1="K566";
		end;
		else if age in (3:6) then do;
			if count le int(0.50*total_agecount) then dx10code1="J189";
			else if count gt int(0.50*total_agecount) and count le int(0.75*total_agecount) then dx10code1="K358";
			else if count gt int(0.75*total_agecount) and count le int(0.875*total_agecount) then dx10code1="N390";
			else dx10code1="Z540";
		end;
		else if age in (7:13) then do;
			if count le int(0.2307692308*total_agecount) then dx10code1="J189";
			else if count gt int(0.2307692308*total_agecount) and count le int(0.5384615385*total_agecount) then dx10code1="K358";
			else if count gt int(0.5384615385*total_agecount) and count le int(0.8461538462*total_agecount) then dx10code1="K566";
			else dx10code1="Z540";
		end;
		else if age in (14:19) then do;
			if count le int(0.4166666667*total_agecount) then dx10code1="K358";
			else if count gt int(0.4166666667*total_agecount) and count le int(0.5833333333*total_agecount) then dx10code1="J189";
			else if count gt int(0.5833333333*total_agecount) and count le int(0.6666666667*total_agecount) then dx10code1="K566";
			else if count gt int(0.6666666667*total_agecount) and count le int(0.9166666667*total_agecount) then dx10code1="N179";
			else dx10code1="I500";
		end;
		else if age in (20:24) then do;
			if count le int(0.3333333333*total_agecount) then dx10code1="J189";
			else if count gt int(0.3333333333*total_agecount) and count le int(0.5833333333*total_agecount) then dx10code1="K358";
			else if count gt int(0.5833333333*total_agecount) and count le int(0.8333333333*total_agecount) then dx10code1="N390";
			else if count gt int(0.8333333333*total_agecount) and count le int(0.9166666667*total_agecount) then dx10code1="K566";
			else dx10code1="Z540";
		end;
		else if age in (25:31) then do;
			if count le int(0.375*total_agecount) then dx10code1="K358";
			else if count gt int(0.375*total_agecount) and count le int(0.625*total_agecount) then dx10code1="K566";
			else if count gt int(0.625*total_agecount) and count le int(0.875*total_agecount) then dx10code1="N390";
			else dx10code1="I214";
		end;
		else if age in (32:52) then do;
			if count le int(0.1428571429*total_agecount) then dx10code1="K358";
			else if count gt int(0.1428571429*total_agecount) and count le int(0.2857142857*total_agecount) then dx10code1="J189";
			else if count gt int(0.2857142857*total_agecount) and count le int(0.4761904762*total_agecount) then dx10code1="Z540";
			else if count gt int(0.4761904762*total_agecount) and count le int(0.6190476191*total_agecount) then dx10code1="K566";
			else if count gt int(0.6190476191*total_agecount) and count le int(0.8095238095*total_agecount) then dx10code1="I500";
			else if count gt int(0.8095238095*total_agecount) and count le int(0.9047619048*total_agecount) then dx10code1="I214";
			else if count gt int(0.9047619048*total_agecount) and count le int(0.9523809524*total_agecount) then dx10code1="M179";
			else dx10code1="N179";
		end;
		else if age in (53:79) then do;
			if count le int(0.1711491443*total_agecount) then dx10code1="I214";
			else if count gt int(0.1711491443*total_agecount) and count le int(0.3105134474*total_agecount) then dx10code1="I500";
			else if count gt int(0.3105134474*total_agecount) and count le int(0.3985330073*total_agecount) then dx10code1="J441";
			else if count gt int(0.3985330073*total_agecount) and count le int(0.5256723716*total_agecount) then dx10code1="I2510";
			else if count gt int(0.5256723716*total_agecount) and count le int(0.6112469438*total_agecount) then dx10code1="J440";
			else if count gt int(0.6112469438*total_agecount) and count le int(0.6674816626*total_agecount) then dx10code1="J189";
			else if count gt int(0.6674816626*total_agecount) and count le int(0.7237163814*total_agecount) then dx10code1="M179";
			else if count gt int(0.7237163814*total_agecount) and count le int(0.7872860636*total_agecount) then dx10code1="N179";
			else if count gt int(0.7872860636*total_agecount) and count le int(0.8435207824*total_agecount) then dx10code1="K566";
			else if count gt int(0.8435207824*total_agecount) and count le int(0.8753056235*total_agecount) then dx10code1="N390";
			else if count gt int(0.8753056235*total_agecount) and count le int(0.9193154034*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9193154034*total_agecount) and count le int(0.9437652812*total_agecount) then dx10code1="M169";
			else if count gt int(0.9437652812*total_agecount) and count le int(0.9633251834*total_agecount) then dx10code1="M170";
			else if count gt int(0.9633251834*total_agecount) and count le int(0.9951100245*total_agecount) then dx10code1="Z515";
			else dx10code1="K358";
		end;
		else if age in (80:89) then do;
			if count le int(0.2407732865*total_agecount) then dx10code1="I500";
			else if count gt int(0.2407732865*total_agecount) and count le int(0.3708260105*total_agecount) then dx10code1="I214";
			else if count gt int(0.3708260105*total_agecount) and count le int(0.4815465729*total_agecount) then dx10code1="N390";
			else if count gt int(0.4815465729*total_agecount) and count le int(0.6028119508*total_agecount) then dx10code1="J189";
			else if count gt int(0.6028119508*total_agecount) and count le int(0.6924428823*total_agecount) then dx10code1="J440";
			else if count gt int(0.6924428823*total_agecount) and count le int(0.7820738137*total_agecount) then dx10code1="J441";
			else if count gt int(0.7820738137*total_agecount) and count le int(0.834797891*total_agecount) then dx10code1="N179";
			else if count gt int(0.834797891*total_agecount) and count le int(0.8717047452*total_agecount) then dx10code1="Z515";
			else if count gt int(0.8717047452*total_agecount) and count le int(0.9103690685*total_agecount) then dx10code1="K566";
			else if count gt int(0.9103690685*total_agecount) and count le int(0.9384885765*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9384885765*total_agecount) and count le int(0.9472759227*total_agecount) then dx10code1="M169";
			else if count gt int(0.9472759227*total_agecount) and count le int(0.9701230229*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9701230229*total_agecount) and count le int(0.9841827768*total_agecount) then dx10code1="M179";
			else dx10code1="M170";
		end;
		else if age in (90:95) then do;
			if count le int(0.3076923077*total_agecount) then dx10code1="I500";
			else if count gt int(0.3076923077*total_agecount) and count le int(0.4319526627*total_agecount) then dx10code1="N390";
			else if count gt int(0.4319526627*total_agecount) and count le int(0.5798816568*total_agecount) then dx10code1="J189";
			else if count gt int(0.5798816568*total_agecount) and count le int(0.7100591716*total_agecount) then dx10code1="I214";
			else if count gt int(0.7100591716*total_agecount) and count le int(0.8165680473*total_agecount) then dx10code1="J440";
			else if count gt int(0.8165680473*total_agecount) and count le int(0.8875739645*total_agecount) then dx10code1="J441";
			else if count gt int(0.8875739645*total_agecount) and count le int(0.9289940828*total_agecount) then dx10code1="N179";
			else if count gt int(0.9289940828*total_agecount) and count le int(0.976331361*total_agecount) then dx10code1="Z515";
			else if count gt int(0.976331361*total_agecount) and count le int(0.9940828402*total_agecount) then dx10code1="K566";
			else dx10code1="Z540";
		end;
		else  do;
			if count le int(0.20*total_agecount) then dx10code1="J189";
			else if count gt int(0.20*total_agecount) and count le int(0.50*total_agecount) then dx10code1="N390";
			else if count gt int(0.50*total_agecount) and count le int(0.60*total_agecount) then dx10code1="J441";
			else if count gt int(0.60*total_agecount) and count le int(0.70*total_agecount) then dx10code1="J440";
			else if count gt int(0.70*total_agecount) and count le int(0.80*total_agecount) then dx10code1="N179";
			else dx10code1="Z515";
		end;
	run;

	data subset_2a;
		set subset_2a_1 subset_2a_2;
	run;

	proc sort data=subset_2b_1 out=temp;
		by key ;
	run;

	data subset_2b_1;
		set temp;
	run;

	proc sort data=subset_2b_1 out=temp;
		by age ;
	run;

	data subset_2b_1;
		set temp;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.6482843137*total_agecount) then dx10code1="P071";
			else if count gt int(0.6482843137*total_agecount) and count le int(0.868872549*total_agecount) then dx10code1="N390";
			else if count gt int(0.868872549*total_agecount) and count le int(0.9705882353*total_agecount) then dx10code1="J189";
			else if count gt int(0.9705882353*total_agecount) and count le int(0.9767156863*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9767156863*total_agecount) and count le int(0.987745098*total_agecount) then dx10code1="I500";
			else if count gt int(0.987745098*total_agecount) and count le int(0.9963235294*total_agecount) then dx10code1="K566";
			else if count gt int(0.9963235294*total_agecount) and count le int(0.9987745098*total_agecount) then dx10code1="Z515";
			else  dx10code1="N179";
		end;
		else if age in (1:2) then do;
			if count le int(0.6190476191*total_agecount) then dx10code1="J189";
			else if count gt int(0.6190476191*total_agecount) and count le int(0.9285714286*total_agecount) then dx10code1="N390";
			else if count gt int(0.9285714286*total_agecount) and count le int(0.9761904762*total_agecount) then dx10code1="Z540";
			else  dx10code1="K566";
		end;
		else if age in (3:6) then do;
			if count le int(0.375*total_agecount) then dx10code1="J189";
			else if count gt int(0.375*total_agecount) and count le int(0.875*total_agecount) then dx10code1="N390";
			else  dx10code1="Z515";
		end;
		else if age in (7:13) then do;
			if count le int(0.4545454546*total_agecount) then dx10code1="J189";
			else if count gt int(0.4545454546*total_agecount) and count le int(0.5454545455*total_agecount) then dx10code1="Z540";
			else if count gt int(0.5454545455*total_agecount) and count le int(0.7272727273*total_agecount) then dx10code1="K358";
			else  dx10code1="N390";
		end;
		else if age in (14:19) then do;
			if count le int(0.1818181818*total_agecount) then dx10code1="O70101";
			else if count gt int(0.1818181818*total_agecount) and count le int(0.3636363636*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.3636363636*total_agecount) and count le int(0.5272727273*total_agecount) then dx10code1="O48001";
			else if count gt int(0.5272727273*total_agecount) and count le int(0.60*total_agecount) then dx10code1="J189";
			else if count gt int(0.60*total_agecount) and count le int(0.6727272727*total_agecount) then dx10code1="K358";
			else if count gt int(0.6727272727*total_agecount) and count le int(0.7272727273*total_agecount) then dx10code1="K566";
			else if count gt int(0.7272727273*total_agecount) and count le int(0.8181818182*total_agecount) then dx10code1="Z540";
			else if count gt int(0.8181818182*total_agecount) and count le int(0.8909090909*total_agecount) then dx10code1="O42021";
			else if count gt int(0.8909090909*total_agecount) and count le int(0.9454545455*total_agecount) then dx10code1="N390";
			else if count gt int(0.9454545455*total_agecount) and count le int(0.9636363636*total_agecount) then dx10code1="N179";
			else  dx10code1="O34201";
		end;
		else if age in (20:24) then do;
			if count le int(0.2173913044*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.2173913044*total_agecount) and count le int(0.2826086957*total_agecount) then dx10code1="Z540";
			else if count gt int(0.2826086957*total_agecount) and count le int(0.3695652174*total_agecount) then dx10code1="J189";
			else if count gt int(0.3695652174*total_agecount) and count le int(0.5217391304*total_agecount) then dx10code1="O42021";
			else if count gt int(0.5217391304*total_agecount) and count le int(0.6739130435*total_agecount) then dx10code1="O70101";
			else if count gt int(0.6739130435*total_agecount) and count le int(0.8043478261*total_agecount) then dx10code1="O48001";
			else if count gt int(0.8043478261*total_agecount) and count le int(0.8695652174*total_agecount) then dx10code1="K358";
			else if count gt int(0.8695652174*total_agecount) and count le int(0.9565217391*total_agecount) then dx10code1="O34201";
			else if count gt int(0.9565217391*total_agecount) and count le int(0.9782608696*total_agecount) then dx10code1="N390";
			else  dx10code1="I500";
		end;
		else if age in (25:31) then do;
			if count le int(0.2278481013*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.2278481013*total_agecount) and count le int(0.4430379747*total_agecount) then dx10code1="O70101";
			else if count gt int(0.4430379747*total_agecount) and count le int(0.6075949367*total_agecount) then dx10code1="O48001";
			else if count gt int(0.6075949367*total_agecount) and count le int(0.7341772152*total_agecount) then dx10code1="O34201";
			else if count gt int(0.7341772152*total_agecount) and count le int(0.835443038*total_agecount) then dx10code1="O42021";
			else if count gt int(0.835443038*total_agecount) and count le int(0.8734177215*total_agecount) then dx10code1="Z540";
			else if count gt int(0.8734177215*total_agecount) and count le int(0.9113924051*total_agecount) then dx10code1="N390";
			else if count gt int(0.9113924051*total_agecount) and count le int(0.9367088608*total_agecount) then dx10code1="K566";
			else if count gt int(0.9367088608*total_agecount) and count le int(0.9746835443*total_agecount) then dx10code1="J189";
			else  dx10code1="K358";
		end;
		else if age in (32:52) then do;
			if count le int(0.3333333333*total_agecount) then dx10code1="O34201";
			else if count gt int(0.3333333333*total_agecount) and count le int(0.3963963964*total_agecount) then dx10code1="Z540";
			else if count gt int(0.3963963964*total_agecount) and count le int(0.4954954955*total_agecount) then dx10code1="O70101";
			else if count gt int(0.4954954955*total_agecount) and count le int(0.5945945946*total_agecount) then dx10code1="Z37000";
			else if count gt int(0.5945945946*total_agecount) and count le int(0.6486486487*total_agecount) then dx10code1="K566";
			else if count gt int(0.6486486487*total_agecount) and count le int(0.7297297297*total_agecount) then dx10code1="N390";
			else if count gt int(0.7297297297*total_agecount) and count le int(0.7657657658*total_agecount) then dx10code1="Z515";
			else if count gt int(0.7657657658*total_agecount) and count le int(0.8288288288*total_agecount) then dx10code1="O42021";
			else if count gt int(0.8288288288*total_agecount) and count le int(0.8468468469*total_agecount) then dx10code1="I500";
			else if count gt int(0.8468468469*total_agecount) and count le int(0.9009009009*total_agecount) then dx10code1="K358";
			else if count gt int(0.9009009009*total_agecount) and count le int(0.954954955*total_agecount) then dx10code1="O48001";
			else if count gt int(0.954954955*total_agecount) and count le int(0.963963964*total_agecount) then dx10code1="I2510";
			else if count gt int(0.963963964*total_agecount) and count le int(0.990990991*total_agecount) then dx10code1="N179";
			else  dx10code1="J441";
		end;
		else if age in (53:79) then do;
			if count le int(0.09895833333*total_agecount) then dx10code1="I2510";
			else if count gt int(0.09895833333*total_agecount) and count le int(0.2369791667*total_agecount) then dx10code1="Z515";
			else if count gt int(0.2369791667*total_agecount) and count le int(0.3567708333*total_agecount) then dx10code1="I500";
			else if count gt int(0.3567708333*total_agecount) and count le int(0.4583333333*total_agecount) then dx10code1="J441";
			else if count gt int(0.4583333333*total_agecount) and count le int(0.5494791667*total_agecount) then dx10code1="I214";
			else if count gt int(0.5494791667*total_agecount) and count le int(0.640625*total_agecount) then dx10code1="Z540";
			else if count gt int(0.640625*total_agecount) and count le int(0.6927083333*total_agecount) then dx10code1="J440";
			else if count gt int(0.6927083333*total_agecount) and count le int(0.7604166667*total_agecount) then dx10code1="N179";
			else if count gt int(0.7604166667*total_agecount) and count le int(0.8307291667*total_agecount) then dx10code1="N390";
			else if count gt int(0.8307291667*total_agecount) and count le int(0.8776041667*total_agecount) then dx10code1="J189";
			else if count gt int(0.8776041667*total_agecount) and count le int(0.9322916667*total_agecount) then dx10code1="K566";
			else if count gt int(0.9322916667*total_agecount) and count le int(0.9609375*total_agecount) then dx10code1="M179";
			else if count gt int(0.9609375*total_agecount) and count le int(0.984375*total_agecount) then dx10code1="M170";
			else if count gt int(0.984375*total_agecount) and count le int(0.9947916667*total_agecount) then dx10code1="M169";
			else  dx10code1="K358";
		end;
		else if age in (80:89) then do;
			if count le int(0.2557003257*total_agecount) then dx10code1="I500";
			else if count gt int(0.2557003257*total_agecount) and count le int(0.3648208469*total_agecount) then dx10code1="Z515";
			else if count gt int(0.3648208469*total_agecount) and count le int(0.490228013*total_agecount) then dx10code1="I214";
			else if count gt int(0.490228013*total_agecount) and count le int(0.5765472313*total_agecount) then dx10code1="J189";
			else if count gt int(0.5765472313*total_agecount) and count le int(0.664495114*total_agecount) then dx10code1="N390";
			else if count gt int(0.664495114*total_agecount) and count le int(0.7442996743*total_agecount) then dx10code1="J440";
			else if count gt int(0.7442996743*total_agecount) and count le int(0.8127035831*total_agecount) then dx10code1="Z540";
			else if count gt int(0.8127035831*total_agecount) and count le int(0.8615635179*total_agecount) then dx10code1="J441";
			else if count gt int(0.8615635179*total_agecount) and count le int(0.9136807818*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9136807818*total_agecount) and count le int(0.9527687296*total_agecount) then dx10code1="N179";
			else if count gt int(0.9527687296*total_agecount) and count le int(0.9853420195*total_agecount) then dx10code1="K566";
			else if count gt int(0.9853420195*total_agecount) and count le int(0.990228013*total_agecount) then dx10code1="M179";
			else if count gt int(0.990228013*total_agecount) and count le int(0.9951140065*total_agecount) then dx10code1="M169";
			else  dx10code1="M170";
		end;
		else if age in (90:95) then do;
			if count le int(0.329305136*total_agecount) then dx10code1="I500";
			else if count gt int(0.329305136*total_agecount) and count le int(0.5105740181*total_agecount) then dx10code1="Z515";
			else if count gt int(0.5105740181*total_agecount) and count le int(0.6374622357*total_agecount) then dx10code1="N390";
			else if count gt int(0.6374622357*total_agecount) and count le int(0.749244713*total_agecount) then dx10code1="J189";
			else if count gt int(0.749244713*total_agecount) and count le int(0.7975830816*total_agecount) then dx10code1="J440";
			else if count gt int(0.7975830816*total_agecount) and count le int(0.8549848943*total_agecount) then dx10code1="N179";
			else if count gt int(0.8549848943*total_agecount) and count le int(0.9093655589*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9093655589*total_agecount) and count le int(0.9425981873*total_agecount) then dx10code1="I214";
			else if count gt int(0.9425981873*total_agecount) and count le int(0.9728096677*total_agecount) then dx10code1="J441";
			else if count gt int(0.9728096677*total_agecount) and count le int(0.9758308157*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9758308157*total_agecount) and count le int(0.9848942598*total_agecount) then dx10code1="K566";
			else if count gt int(0.9848942598*total_agecount) and count le int(0.9939577039*total_agecount) then dx10code1="M179";
			else if count gt int(0.9939577039*total_agecount) and count le int(0.996978852*total_agecount) then dx10code1="K358";
			else  dx10code1="M169";
		end;
		else  do;
			if count le int(0.2444444444*total_agecount) then dx10code1="Z515";
			else if count gt int(0.2444444444*total_agecount) and count le int(0.4888888889*total_agecount) then dx10code1="I500";
			else if count gt int(0.4888888889*total_agecount) and count le int(0.6666666667*total_agecount) then dx10code1="J189";
			else if count gt int(0.6666666667*total_agecount) and count le int(0.7777777778*total_agecount) then dx10code1="N390";
			else if count gt int(0.7777777778*total_agecount) and count le int(0.8444444444*total_agecount) then dx10code1="I214";
			else if count gt int(0.8444444444*total_agecount) and count le int(0.8888888889*total_agecount) then dx10code1="J440";
			else if count gt int(0.8888888889*total_agecount) and count le int(0.9333333333*total_agecount) then dx10code1="J441";
			else if count gt int(0.9333333333*total_agecount) and count le int(0.9555555556*total_agecount) then dx10code1="N179";
			else if count gt int(0.9555555556*total_agecount) and count le int(0.9777777778*total_agecount) then dx10code1="M179";
			else  dx10code1="Z540";
		end;
	run;

	proc sort data=subset_2b_2 out=temp;
		by key ;
	run;

	data subset_2b_2;
		set temp;
	run;

	proc sort data=subset_2b_2 out=temp;
		by age ;
	run;

	data subset_2b_2;
		set temp;
		by age;

		if first.age then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if age eq 0 then do;
			if count le int(0.5908683975*total_agecount) then dx10code1="P071";
			else if count gt int(0.5908683975*total_agecount) and count le int(0.8504923903*total_agecount) then dx10code1="N390";
			else if count gt int(0.8504923903*total_agecount) and count le int(0.9579230081*total_agecount) then dx10code1="J189";
			else if count gt int(0.9579230081*total_agecount) and count le int(0.9794091316*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9794091316*total_agecount) and count le int(0.9901521934*total_agecount) then dx10code1="I500";
			else if count gt int(0.9901521934*total_agecount) and count le int(0.9946284691*total_agecount) then dx10code1="K566";
			else  dx10code1="Z515";
		end;
		else if age in (1:2) then do;
			if count le int(0.7358490566*total_agecount) then dx10code1="J189";
			else if count gt int(0.7358490566*total_agecount) and count le int(0.8490566038*total_agecount) then dx10code1="N390";
			else if count gt int(0.8490566038*total_agecount) and count le int(0.9433962264*total_agecount) then dx10code1="Z540";
			else if count gt int(0.9433962264*total_agecount) and count le int(0.9811320755*total_agecount) then dx10code1="K566";
			else  dx10code1="I500";
		end;
		else if age in (3:6) then do;
			if count le int(0.4285714286*total_agecount) then dx10code1="J189";
			else if count gt int(0.4285714286*total_agecount) and count le int(0.8571428571*total_agecount) then dx10code1="K358";
			else  dx10code1="K566";
		end;
		else if age in (7:13) then do;
			if count le int(0.2727272727*total_agecount) then dx10code1="J189";
			else if count gt int(0.2727272727*total_agecount) and count le int(0.5454545455*total_agecount) then dx10code1="Z540";
			else if count gt int(0.5454545455*total_agecount) and count le int(0.6363636364*total_agecount) then dx10code1="K358";
			else if count gt int(0.6363636364*total_agecount) and count le int(0.9090909091*total_agecount) then dx10code1="K566";
			else  dx10code1="Z515";
		end;
		else if age in (14:19) then do;
			if count le int(0.25*total_agecount) then dx10code1="J189";
			else if count gt int(0.25*total_agecount) and count le int(0.375*total_agecount) then dx10code1="K358";
			else if count gt int(0.375*total_agecount) and count le int(0.625*total_agecount) then dx10code1="K566";
			else if count gt int(0.625*total_agecount) and count le int(0.875*total_agecount) then dx10code1="I500";
			else  dx10code1="N179";
		end;
		else if age in (20:24) then do;
			if count le int(0.4285714286*total_agecount) then dx10code1="Z540";
			else if count gt int(0.4285714286*total_agecount) and count le int(0.6428571429*total_agecount) then dx10code1="J189";
			else if count gt int(0.6428571429*total_agecount) and count le int(0.7857142857*total_agecount) then dx10code1="K358";
			else if count gt int(0.7857142857*total_agecount) and count le int(0.8571428571*total_agecount) then dx10code1="N390";
			else if count gt int(0.8571428571*total_agecount) and count le int(0.9285714286*total_agecount) then dx10code1="K566";
			else  dx10code1="N179";
		end;
		else if age in (25:31) then do;
			if count le int(0.3333333333*total_agecount) then dx10code1="Z540";
			else if count gt int(0.3333333333*total_agecount) and count le int(0.60*total_agecount) then dx10code1="N390";
			else if count gt int(0.60*total_agecount) and count le int(0.7333333333*total_agecount) then dx10code1="K566";
			else if count gt int(0.7333333333*total_agecount) and count le int(0.8666666667*total_agecount) then dx10code1="Z515";
			else if count gt int(0.8666666667*total_agecount) and count le int(0.9333333333*total_agecount) then dx10code1="I500";
			else  dx10code1="N179";
		end;
		else if age in (32:52) then do;
			if count le int(0.1764705882*total_agecount) then dx10code1="Z540";
			else if count gt int(0.1764705882*total_agecount) and count le int(0.2647058824*total_agecount) then dx10code1="K566";
			else if count gt int(0.2647058824*total_agecount) and count le int(0.3823529412*total_agecount) then dx10code1="J189";
			else if count gt int(0.3823529412*total_agecount) and count le int(0.4705882353*total_agecount) then dx10code1="N390";
			else if count gt int(0.4705882353*total_agecount) and count le int(0.5882352941*total_agecount) then dx10code1="Z515";
			else if count gt int(0.5882352941*total_agecount) and count le int(0.7058823529*total_agecount) then dx10code1="I500";
			else if count gt int(0.7058823529*total_agecount) and count le int(0.8529411765*total_agecount) then dx10code1="I214";
			else if count gt int(0.8529411765*total_agecount) and count le int(0.9705882353*total_agecount) then dx10code1="I2510";
			else  dx10code1="J440";
		end;
		else if age in (53:79) then do;
			if count le int(0.1596958175*total_agecount) then dx10code1="I2510";
			else if count gt int(0.1596958175*total_agecount) and count le int(0.2908745247*total_agecount) then dx10code1="Z515";
			else if count gt int(0.2908745247*total_agecount) and count le int(0.4068441065*total_agecount) then dx10code1="I500";
			else if count gt int(0.4068441065*total_agecount) and count le int(0.5285171103*total_agecount) then dx10code1="J441";
			else if count gt int(0.5285171103*total_agecount) and count le int(0.6235741445*total_agecount) then dx10code1="I214";
			else if count gt int(0.6235741445*total_agecount) and count le int(0.6958174905*total_agecount) then dx10code1="Z540";
			else if count gt int(0.6958174905*total_agecount) and count le int(0.7604562738*total_agecount) then dx10code1="J440";
			else if count gt int(0.7604562738*total_agecount) and count le int(0.8136882129*total_agecount) then dx10code1="N179";
			else if count gt int(0.8136882129*total_agecount) and count le int(0.8631178707*total_agecount) then dx10code1="N390";
			else if count gt int(0.8631178707*total_agecount) and count le int(0.9144486692*total_agecount) then dx10code1="J189";
			else if count gt int(0.9144486692*total_agecount) and count le int(0.9600760456*total_agecount) then dx10code1="K566";
			else if count gt int(0.9600760456*total_agecount) and count le int(0.9771863118*total_agecount) then dx10code1="M179";
			else if count gt int(0.9771863118*total_agecount) and count le int(0.9904942966*total_agecount) then dx10code1="M170";
			else  dx10code1="M169";
		end;
		else if age in (80:89) then do;
			if count le int(0.2195845697*total_agecount) then dx10code1="I500";
			else if count gt int(0.2195845697*total_agecount) and count le int(0.3486646884*total_agecount) then dx10code1="Z515";
			else if count gt int(0.3486646884*total_agecount) and count le int(0.4391691395*total_agecount) then dx10code1="I214";
			else if count gt int(0.4391691395*total_agecount) and count le int(0.5385756677*total_agecount) then dx10code1="J189";
			else if count gt int(0.5385756677*total_agecount) and count le int(0.6290801187*total_agecount) then dx10code1="N390";
			else if count gt int(0.6290801187*total_agecount) and count le int(0.7181008902*total_agecount) then dx10code1="J440";
			else if count gt int(0.7181008902*total_agecount) and count le int(0.7804154303*total_agecount) then dx10code1="Z540";
			else if count gt int(0.7804154303*total_agecount) and count le int(0.850148368*total_agecount) then dx10code1="J441";
			else if count gt int(0.850148368*total_agecount) and count le int(0.9020771513*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9020771513*total_agecount) and count le int(0.9584569733*total_agecount) then dx10code1="N179";
			else if count gt int(0.9584569733*total_agecount) and count le int(0.9866468843*total_agecount) then dx10code1="K566";
			else if count gt int(0.9866468843*total_agecount) and count le int(0.9940652819*total_agecount) then dx10code1="M179";
			else if count gt int(0.9940652819*total_agecount) and count le int(0.9985163205*total_agecount) then dx10code1="M169";
			else  dx10code1="M170";
		end;
		else if age in (90:95) then do;
			if count le int(0.3164556962*total_agecount) then dx10code1="I500";
			else if count gt int(0.3164556962*total_agecount) and count le int(0.5189873418*total_agecount) then dx10code1="Z515";
			else if count gt int(0.5189873418*total_agecount) and count le int(0.6329113924*total_agecount) then dx10code1="N390";
			else if count gt int(0.6329113924*total_agecount) and count le int(0.7278481013*total_agecount) then dx10code1="J189";
			else if count gt int(0.7278481013*total_agecount) and count le int(0.7974683544*total_agecount) then dx10code1="J440";
			else if count gt int(0.7974683544*total_agecount) and count le int(0.8291139241*total_agecount) then dx10code1="N179";
			else if count gt int(0.8291139241*total_agecount) and count le int(0.8544303798*total_agecount) then dx10code1="Z540";
			else if count gt int(0.8544303798*total_agecount) and count le int(0.917721519*total_agecount) then dx10code1="I214";
			else if count gt int(0.917721519*total_agecount) and count le int(0.9556962025*total_agecount) then dx10code1="J441";
			else if count gt int(0.9556962025*total_agecount) and count le int(0.9810126582*total_agecount) then dx10code1="I2510";
			else if count gt int(0.9810126582*total_agecount) and count le int(0.9936708861*total_agecount) then dx10code1="K566";
			else  dx10code1="M179";
		end;
		else  do;
			if count le int(0.2666666667*total_agecount) then dx10code1="Z515";
			else if count gt int(0.2666666667*total_agecount) and count le int(0.4666666667*total_agecount) then dx10code1="I500";
			else if count gt int(0.4666666667*total_agecount) and count le int(0.7333333333*total_agecount) then dx10code1="J189";
			else if count gt int(0.7333333333*total_agecount) and count le int(0.9333333333*total_agecount) then dx10code1="N390";
			else  dx10code1="N179";
		end;
	run;

	data subset_2b;
		set subset_2b_1 subset_2b_2;
	run;

	data subset_2;
		set subset_2a subset_2b;
	run;
%mend createCode1DupPid;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating dxpref1 variable*/
%macro createDXpref1;
	data hospitalization;
		length dxpref1 $1;
		set hospitalization;
	run;

	proc sql noprint;
		create table temp as
		select *,count(dx10code1) as dx10code1count from hospitalization group by dx10code1;
	quit;

	proc sort data=temp;
		by dx10code1;
	run;

	data intermediate;
		set temp;
		by dx10code1;

		if first.dx10code1 then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if dx10code1 eq "I214" then do;
			if count le int(0.65250965251*dx10code1count) then dxpref1="Q";
			else dxpref1="C";
		end;
		else if dx10code1 eq "I2510" then do;
			if count le int(0.8571428571*dx10code1count) then dxpref1="Q";
			else dxpref1="C";
		end;
		else if dx10code1 eq "I500" then do;
			if count le int(0.6878048781*dx10code1count) then dxpref1="Q";
			else dxpref1="C";
		end;
		else if dx10code1 eq "J189" then do;
			if count le int(0.6626686657*dx10code1count) then dxpref1="Q";
			else dxpref1="C";
		end;
		else if dx10code1 eq "J440" then do;
			if count le int(0.845659164*dx10code1count) then dxpref1="Q";
			else dxpref1="C";
		end;
		else if dx10code1 eq "J441" then do;
			if count le int(0.5337837838*dx10code1count) then dxpref1="Q";
			else if count gt int(0.5337837838*dx10code1count) and count le int(0.9932432*dx10code1count) then dxpref1="Q";
			else dxpref1="J";
		end;
		else if dx10code1 eq "K358" then dxpref1="Q";
		else if dx10code1 eq "K566" then do;
			if count le int(0.9208333333*dx10code1count) then dxpref1="Q";
			else if count gt int(0.9208333333*dx10code1count) and count le int(0.979166*dx10code1count) then dxpref1="C";
			else if count gt int(0.979166*dx10code1count) and count le int(0.99166*dx10code1count) then dxpref1="V";
			else dxpref1="A";
		end;
		else if dx10code1 eq "M170" then dxpref1="H";
		else if dx10code1 eq "M179" then dxpref1="Q";
		else if dx10code1 eq "N179" then do;
			if count le int(0.8988764045*dx10code1count) then dxpref1="C";
			else dxpref1="Q";
		end;
		else if dx10code1 eq "N390" then do;
			if count le int(0.8931750742*dx10code1count) then dxpref1="Q";
			else dxpref1="C";
		end;
		else if dx10code1 eq "O42021" then do;
			if count le int(0.7142857143*dx10code1count) then dxpref1="I";
			else dxpref1="Q";
		end;
		else if dx10code1 eq "O48001" then do;
			if count le int(0.9701492537*dx10code1count) then dxpref1="I";
			else dxpref1="Q";
		end;
		else if dx10code1 eq "O68001" then dxpref1="Q";
		else if dx10code1 eq "P071" then dxpref1="Q";
		else if dx10code1 eq "Z37000" then dxpref1="I";
		else if dx10code1 eq "Z515" then do;
			if count le int(0.9962443666*dx10code1count) then dxpref1="8";
			else if count gt int(0.9962443666*dx10code1count) and count le int(0.997466*dx10code1count) then dxpref1="W";
			else if count gt int(0.997466*dx10code1count) and count le int(0.9987481*dx10code1count) then dxpref1="C";
			else if count gt int(0.9987481*dx10code1count) and count le int(0.9994992*dx10code1count) then dxpref1="M";
			else dxpref1="Q";
		end;
		else if dx10code1 eq "Z540" then dxpref1="Q";
	run;

	data hospitalization;
		set intermediate (drop=dx10code1count count);
	run;
%mend createDXpref1;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Create dxtype1 variable*/
%macro createDXType1;
	data hospitalization;
		length dxtype1 $1;
		set hospitalization;
		dxtype1="M";
	run;
%mend createDXType1;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Create dx10code2 variable*/
%macro createDX10code2;
	data hospitalization;
		length dx10code2 $7;
		set hospitalization;
	run;

	proc sql noprint;
		create table temp as
		select *,count(dx10code1) as dx10code1count from hospitalization group by dx10code1;
	quit;

	proc sort data=temp;
		by dx10code1;
	run;

	data intermediate;
		set temp;
		by dx10code1;

		if first.dx10code1 then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if dx10code1 eq "I214" then do;
			if count le int(0.9244777718*dx10code1count) then dx10code2="R9431";
			else if count gt int(0.9244777718*dx10code1count) and count le int(0.9622388859*dx10code1count) then dx10code2="I2510";
			else if count gt int(0.9622388859*dx10code1count) and count le int(0.9791108731*dx10code1count) then dx10code2="E1152";
			else if count gt int(0.9791108731*dx10code1count) and count le int(0.9902249598*dx10code1count) then dx10code2="R9430";
			else dx10code2="I500";
		end;
		else if dx10code1 eq "I2510" then do;
			if count le int(0.2794752574*dx10code1count) then dx10code2="I100";
			else if count gt int(0.2794752574*dx10code1count) and count le int(0.5245765526*dx10code1count) then dx10code2="E1152";
			else if count gt int(0.5245765526*dx10code1count) and count le int(0.7658585188*dx10code1count) then dx10code2="I214";
			else if count gt int(0.7658585188*dx10code1count) and count le int(0.9217867818*dx10code1count) then dx10code2="I200";
			else dx10code2="I2088";
		end;
		else if dx10code1 eq "I500" then do;
			if count le int(0.4195839043*dx10code1count) then dx10code2="E1152";
			else if count gt int(0.4195839043*dx10code1count) and count le int(0.6554129812*dx10code1count) then dx10code2="I4890";
			else if count gt int(0.6554129812*dx10code1count) and count le int(0.7715211162*dx10code1count) then dx10code2="J189";
			else if count gt int(0.7715211162*dx10code1count) and count le int(0.8865080354*dx10code1count) then dx10code2="I100";
			else dx10code2="N179";
		end;
		else if dx10code1 eq "J189" then do;
			if count le int(0.3440688776*dx10code1count) then dx10code2="I500";
			else if count gt int(0.3440688776*dx10code1count) and count le int(0.5188137755*dx10code1count) then dx10code2="N179";
			else if count gt int(0.5188137755*dx10code1count) and count le int(0.6916454082*dx10code1count) then dx10code2="N390";
			else if count gt int(0.6916454082*dx10code1count) and count le int(0.8520408163*dx10code1count) then dx10code2="I100";
			else dx10code2="J90";
		end;
		else if dx10code1 eq "J440" then do;
			if count le int(0.8611739365*dx10code1count) then dx10code2="J189";
			else if count gt int(0.8611739365*dx10code1count) and count le int(0.9225632741*dx10code1count) then dx10code2="J180";
			else if count gt int(0.9225632741*dx10code1count) and count le int(0.9541195477*dx10code1count) then dx10code2="J181";
			else if count gt int(0.9541195477*dx10code1count) and count le int(0.9815831987*dx10code1count) then dx10code2="J159";
			else dx10code2="J209";
		end;
		else if dx10code1 eq "J441" then do;
			if count le int(0.3506637168*dx10code1count) then dx10code2="I500";
			else if count gt int(0.3506637168*dx10code1count) and count le int(0.6530235988*dx10code1count) then dx10code2="I100";
			else if count gt int(0.6530235988*dx10code1count) and count le int(0.8053097345*dx10code1count) then dx10code2="E119";
			else if count gt int(0.8053097345*dx10code1count) and count le int(0.9177728614*dx10code1count) then dx10code2="I4890";
			else dx10code2="E1152";
		end;
		else if dx10code1 eq "K358" then do;
			if count le int(0.5036231884*dx10code1count) then dx10code2="K429";
			else if count gt int(0.5036231884*dx10code1count) and count le int(0.6956521739*dx10code1count) then dx10code2="I100";
			else if count gt int(0.6956521739*dx10code1count) and count le int(0.8134057971*dx10code1count) then dx10code2="E119";
			else if count gt int(0.8134057971*dx10code1count) and count le int(0.9112318841*dx10code1count) then dx10code2="K913";
			else dx10code2="Z33";
		end;
		else if dx10code1 eq "K566" then do;
			if count le int(0.2780656304*dx10code1count) then dx10code2="K509";
			else if count gt int(0.2780656304*dx10code1count) and count le int(0.5284974093*dx10code1count) then dx10code2="I100";
			else if count gt int(0.5284974093*dx10code1count) and count le int(0.7098445596*dx10code1count) then dx10code2="Z850";
			else if count gt int(0.7098445596*dx10code1count) and count le int(0.8756476684*dx10code1count) then dx10code2="E119";
			else dx10code2="N390";
		end;
		else if dx10code1 eq "M169" then do;
			if count le int(0.5652941177*dx10code1count) then dx10code2="I100";
			else if count gt int(0.5652941177*dx10code1count) and count le int(0.7605882353*dx10code1count) then dx10code2="E119";
			else if count gt int(0.7605882353*dx10code1count) and count le int(0.8611764706*dx10code1count) then dx10code2="Z501";
			else if count gt int(0.8611764706*dx10code1count) and count le int(0.9476470588*dx10code1count) then dx10code2="D649";
			else dx10code2="G4730";
		end;
		else if dx10code1 eq "M170" then do;
			if count le int(0.4344555874*dx10code1count) then dx10code2="Z9661";
			else if count gt int(0.4344555874*dx10code1count) and count le int(0.7550143267*dx10code1count) then dx10code2="I100";
			else if count gt int(0.7550143267*dx10code1count) and count le int(0.9151146132*dx10code1count) then dx10code2="E119";
			else if count gt int(0.9151146132*dx10code1count) and count le int(0.9598853868*dx10code1count) then dx10code2="D649";
			else dx10code2="M211";
		end;
		else if dx10code1 eq "M179" then do;
			if count le int(0.5358757062*dx10code1count) then dx10code2="I100";
			else if count gt int(0.5358757062*dx10code1count) and count le int(0.7951977401*dx10code1count) then dx10code2="E119";
			else if count gt int(0.7951977401*dx10code1count) and count le int(0.8861581921*dx10code1count) then dx10code2="Z501";
			else if count gt int(0.8861581921*dx10code1count) and count le int(0.9514124294*dx10code1count) then dx10code2="M211";
			else dx10code2="G4730";
		end;
		else if dx10code1 eq "N179" then do;
			if count le int(0.4347826087*dx10code1count) then dx10code2="E1128";
			else if count gt int(0.4347826087*dx10code1count) and count le int(0.64*dx10code1count) then dx10code2="E860";
			else if count gt int(0.64*dx10code1count) and count le int(0.8394202899*dx10code1count) then dx10code2="N189";
			else if count gt int(0.8394202899*dx10code1count) and count le int(0.9234782609*dx10code1count) then dx10code2="N390";
			else dx10code2="E875";
		end;
		else if dx10code1 eq "N390" then do;
			if count le int(0.6552384267*dx10code1count) then dx10code2="B962";
			else if count gt int(0.6552384267*dx10code1count) and count le int(0.7758440654*dx10code1count) then dx10code2="B961";
			else if count gt int(0.7758440654*dx10code1count) and count le int(0.874173338*dx10code1count) then dx10code2="B9681";
			else if count gt int(0.874173338*dx10code1count) and count le int(0.9443090846*dx10code1count) then dx10code2="N179";
			else dx10code2="B965";
		end;
		else if dx10code1 eq "O34201" then do;
			if count le int(0.6988196988*dx10code1count) then dx10code2="Z37000";
			else if count gt int(0.6988196988*dx10code1count) and count le int(0.8865486366*dx10code1count) then dx10code2="Z302";
			else if count gt int(0.8865486366*dx10code1count) and count le int(0.9505494506*dx10code1count) then dx10code2="O24801";
			else if count gt int(0.9505494506*dx10code1count) and count le int(0.9755799756*dx10code1count) then dx10code2="Z3580";
			else dx10code2="O32101";
		end;
		else if dx10code1 eq "O42021" then do;
			if count le int(0.3595143707*dx10code1count) then dx10code2="Z37000";
			else if count gt int(0.3595143707*dx10code1count) and count le int(0.6818632309*dx10code1count) then dx10code2="O70101";
			else if count gt int(0.6818632309*dx10code1count) and count le int(0.8597621407*dx10code1count) then dx10code2="O70001";
			else if count gt int(0.8597621407*dx10code1count) and count le int(0.9415262636*dx10code1count) then dx10code2="O62301";
			else dx10code2="O68001";
		end;
		else if dx10code1 eq "O48001" then do;
			if count le int(0.3851626016*dx10code1count) then dx10code2="Z37000";
			else if count gt int(0.3851626016*dx10code1count) and count le int(0.7069105691*dx10code1count) then dx10code2="O70101";
			else if count gt int(0.7069105691*dx10code1count) and count le int(0.868495935*dx10code1count) then dx10code2="O70001";
			else if count gt int(0.868495935*dx10code1count) and count le int(0.9398373984*dx10code1count) then dx10code2="O68001";
			else dx10code2="O68101";
		end;
		else if dx10code1 eq "O68001" then do;
			if count le int(0.4002116402*dx10code1count) then dx10code2="Z37000";
			else if count gt int(0.4002116402*dx10code1count) and count le int(0.6416931217*dx10code1count) then dx10code2="O70101";
			else if count gt int(0.6416931217*dx10code1count) and count le int(0.7942857143*dx10code1count) then dx10code2="O48001";
			else if count gt int(0.7942857143*dx10code1count) and count le int(0.9062433862*dx10code1count) then dx10code2="O42021";
			else dx10code2="O70001";
		end;
		else if dx10code1 eq "O70001" then do;
			if count le int(0.8484307601*dx10code1count) then dx10code2="Z37000";
			else if count gt int(0.8484307601*dx10code1count) and count le int(0.8995983936*dx10code1count) then dx10code2="Z2238";
			else if count gt int(0.8995983936*dx10code1count) and count le int(0.949427339*dx10code1count) then dx10code2="O69801";
			else if count gt int(0.949427339*dx10code1count) and count le int(0.9767960732*dx10code1count) then dx10code2="O62301";
			else dx10code2="O48001";
		end;
		else if dx10code1 eq "O70101" then do;
			if count le int(0.8338988528*dx10code1count) then dx10code2="Z37000";
			else if count gt int(0.8338988528*dx10code1count) and count le int(0.8843108741*dx10code1count) then dx10code2="Z2238";
			else if count gt int(0.8843108741*dx10code1count) and count le int(0.933511068*dx10code1count) then dx10code2="O69801";
			else if count gt int(0.933511068*dx10code1count) and count le int(0.9671190822*dx10code1count) then dx10code2="O68101";
			else dx10code2="O62301";
		end;
		else if dx10code1 eq "P071" then do;
			if count le int(0.7477563231*dx10code1count) then dx10code2="P073";
			else if count gt int(0.7477563231*dx10code1count) and count le int(0.8614359532*dx10code1count) then dx10code2="P0599";
			else if count gt int(0.8614359532*dx10code1count) and count le int(0.9439760675*dx10code1count) then dx10code2="Z38000";
			else if count gt int(0.9439760675*dx10code1count) and count le int(0.9760674463*dx10code1count) then dx10code2="Z38010";
			else dx10code2="P072";
		end;		
		else if dx10code1 eq "Z37000" then do;
			if count le int(0.6662850601*dx10code1count) then dx10code2="Z2238";
			else if count gt int(0.6662850601*dx10code1count) and count le int(0.8082427018*dx10code1count) then dx10code2="Z292";
			else if count gt int(0.8082427018*dx10code1count) and count le int(0.9227246709*dx10code1count) then dx10code2="Z3580";
			else if count gt int(0.9227246709*dx10code1count) and count le int(0.9736691471*dx10code1count) then dx10code2="Z291";
			else dx10code2="Z352";
		end;
		else if dx10code1 eq "Z38000" then do;
			if count le int(0.472399635*dx10code1count) then dx10code2="P082";
			else if count gt int(0.472399635*dx10code1count) and count le int(0.7002737226*dx10code1count) then dx10code2="P081";
			else if count gt int(0.7002737226*dx10code1count) and count le int(0.8613138686*dx10code1count) then dx10code2="Z412";
			else if count gt int(0.8613138686*dx10code1count) and count le int(0.9457116788*dx10code1count) then dx10code2="P599";
			else dx10code2="Q381";
		end;
		else if dx10code1 eq "Z38010" then do;
			if count le int(0.3162939297*dx10code1count) then dx10code2="P082";
			else if count gt int(0.3162939297*dx10code1count) and count le int(0.6108626198*dx10code1count) then dx10code2="P081";
			else if count gt int(0.6108626198*dx10code1count) and count le int(0.8230031949*dx10code1count) then dx10code2="Z412";
			else if count gt int(0.8230031949*dx10code1count) and count le int(0.9226837061*dx10code1count) then dx10code2="P599";
			else dx10code2="P080";
		end;
		else if dx10code1 eq "Z515" then do;
			if count le int(0.3791804051*dx10code1count) then dx10code2="C3499";
			else if count gt int(0.3791804051*dx10code1count) and count le int(0.5666509656*dx10code1count) then dx10code2="I500";
			else if count gt int(0.5666509656*dx10code1count) and count le int(0.7159679699*dx10code1count) then dx10code2="J189";
			else if count gt int(0.7159679699*dx10code1count) and count le int(0.8591615638*dx10code1count) then dx10code2="A419";
			else dx10code2="J690";
		end;
		else if dx10code1 eq "Z540" then do;
			if count le int(0.4498777506*dx10code1count) then dx10code2="I2510";
			else if count gt int(0.4498777506*dx10code1count) and count le int(0.6780766096*dx10code1count) then dx10code2="K8010";
			else if count gt int(0.6780766096*dx10code1count) and count le int(0.7881010595*dx10code1count) then dx10code2="C679";
			else if count gt int(0.7881010595*dx10code1count) and count le int(0.8964955175*dx10code1count) then dx10code2="Z501";
			else dx10code2="S72080";
		end;
	run;

	data hospitalization;
		set intermediate (drop=dx10code1count count);
	run;
%mend createDX10code2;



/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating dxpref2 variable*/
%macro createDXpref2;
	data hospitalization;
		length dxpref2 $1;
		set hospitalization;
	run;

	proc sql noprint;
		create table temp as
		select *,count(dx10code2) as dx10code2count from hospitalization group by dx10code2;
	quit;

	proc sort data=temp;
		by dx10code2;
	run;


	data intermediate;
		set temp;
		by dx10code2;

		if first.dx10code2 then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if dx10code2 eq "A419" then do;
			if count le int(0.5294117647*dx10code2count) then dxpref2="C";
			else if count gt int(0.5294117647*dx10code2count) and count le int(0.9411764706*dx10code2count) then dxpref2="Q";
			else if count gt int(0.9411764706*dx10code2count) and count le int(0.974789916*dx10code2count) then dxpref2="6";
			else dxpref2="A";
		end;
		else if dx10code2 eq "B962" then dxpref2="Q";
		else if dx10code2 eq "C3499" then do;
			if count le int(0.756097561*dx10code2count) then dxpref2="C";
			else if count gt int(0.756097561*dx10code2count) and count le int(0.993902439*dx10code2count) then dxpref2="Q";
			else dxpref2="A";
		end;
		else if dx10code2 eq "C679" then do;
			if count le int(0.92*dx10code2count) then dxpref2="C";
			else dxpref2="Q";
		end;
		else if dx10code2 eq "D649" then do;
			if count le int(0.9935483871*dx10code2count) then dxpref2="6";
			else dxpref2="A";
		end;
		else if dx10code2 eq "E1128" then do;
			if count le int(0.6666666667*dx10code2count) then dxpref2="Q";
			else dxpref2="C";
		end;
		else if dx10code2 eq "E1152" then dxpref2="Q";
		else if dx10code2 eq "E119" then dxpref2="Q";
		else if dx10code2 eq "E860" then do;
			if count le int(0.40*dx10code2count) then dxpref2="6";
			else if count gt int(0.40*dx10code2count) and count le int(0.70*dx10code2count) then dxpref2="C";
			else if count gt int(0.70*dx10code2count) and count le int(0.90*dx10code2count) then dxpref2="A";
			else dxpref2="Q";
		end;
		else if dx10code2 eq "E875" then do;
			if count le int(0.75*dx10code2count) then dxpref2="6";
			else dxpref2="C";
		end;
		else if dx10code2 eq "G4730" then do;
			if count le int(0.9310344828*dx10code2count) then dxpref2="Q";
			else dxpref2="6";
		end;
		else if dx10code2 eq "I100" then do;
			if count le int(0.75*dx10code2count) then dxpref2="Q";
			else dxpref2="A";
		end;
		else if dx10code2 eq "I200" then do;
			if count le int(0.7647058824*dx10code2count) then dxpref2="Q";
			else if count gt int(0.7647058824*dx10code2count) and count le int(0.9411764706*dx10code2count) then dxpref2="6";
			else dxpref2="5";
		end;
		else if dx10code2 eq "I2088" then do;
			if count le int(0.5714285714*dx10code2count) then dxpref2="Q";
			else dxpref2="6";
		end;
		else if dx10code2 eq "I214" then do;
			if count le int(0.4026845638*dx10code2count) then dxpref2="Q";
			else if count gt int(0.4026845638*dx10code2count) and count le int(0.7516778524*dx10code2count) then dxpref2="6";
			else if count gt int(0.7516778524*dx10code2count) and count le int(0.8926174497*dx10code2count) then dxpref2="5";
			else dxpref2="C";
		end;
		else if dx10code2 eq "I2510" then do;
			if count le int(0.7142857143*dx10code2count) then dxpref2="Q";
			else if count gt int(0.8571428571*dx10code2count) and count le int(0.9411764706*dx10code2count) then dxpref2="6";
			else dxpref2="C";
		end;
		else if dx10code2 eq "I4890" then do;
			if count le int(0.9496402878*dx10code2count) then dxpref2="6";
			else if count gt int(0.9496402878*dx10code2count) and count le int(0.9712230216*dx10code2count) then dxpref2="Q";
			else if count gt int(0.9712230216*dx10code2count) and count le int(0.9820143885*dx10code2count) then dxpref2="5";
			else if count gt int(0.9820143885*dx10code2count) and count le int(0.9928057554*dx10code2count) then dxpref2="A";
			else dxpref2="C";
		end;
		else if dx10code2 eq "I500" then do;
			if count le int(0.5308056872*dx10code2count) then dxpref2="Q";
			else if count gt int(0.5308056872*dx10code2count) and count le int(0.8104265403*dx10code2count) then dxpref2="C";
			else if count gt int(0.8104265403*dx10code2count) and count le int(0.9857819905*dx10code2count) then dxpref2="6";
			else dxpref2="A";
		end;
		else if dx10code2 eq "J159" then do;
			if count le int(0.75*dx10code2count) then dxpref2="Q";
			else dxpref2="C";
		end;
		else if dx10code2 eq "J180" then do;
			if count le int(0.67647058824*dx10code2count) then dxpref2="Q";
			else dxpref2="C";
		end;
		else if dx10code2 eq "J181" then do;
			if count le int(0.6875*dx10code2count) then dxpref2="C";
			else if count gt int(0.6875*dx10code2count) and count le int(0.9375*dx10code2count) then dxpref2="Q";
			else dxpref2="6";
		end;
		else if dx10code2 eq "J189" then do;
			if count le int(0.7425474255*dx10code2count) then dxpref2="Q";
			else if count gt int(0.7425474255*dx10code2count) and count le int(0.9485094851*dx10code2count) then dxpref2="C";
			else if count gt int(0.9485094851*dx10code2count) and count le int(0.9945799458*dx10code2count) then dxpref2="6";
			else if count gt int(0.9945799458*dx10code2count) and count le int(0.9986449865*dx10code2count) then dxpref2="A";
			else dxpref2="5";
		end;
		else if dx10code2 eq "J209" then do;
			if count le int(0.9375*dx10code2count) then dxpref2="Q";
			else dxpref2="6";
		end;
		else if dx10code2 eq "J690" then do;
			if count le int(0.5814977974*dx10code2count) then dxpref2="Q";
			else if count gt int(0.5814977974*dx10code2count) and count le int(0.9471365639*dx10code2count) then dxpref2="C";
			else if count gt int(0.9471365639*dx10code2count) and count le int(0.9911894273*dx10code2count) then dxpref2="6";
			else if count gt int(0.9911894273*dx10code2count) and count le int(0.9955947137*dx10code2count) then dxpref2="5";
			else dxpref2="A";
		end;
		else if dx10code2 eq "J90" then do;
			if count le int(0.8928571429*dx10code2count) then dxpref2="6";
			else if count gt int(0.8928571429*dx10code2count) and count le int(0.9642857143*dx10code2count) then dxpref2="Q";
			else dxpref2="C";
		end;
		else if dx10code2 eq "K429" then dxpref2="Q";
		else if dx10code2 eq "K509" then dxpref2="Q";
		else if dx10code2 eq "K8010" then dxpref2="Q";
		else if dx10code2 eq "K913" then do;
			if count le int(0.9896*dx10code2count) then dxpref2="6";
			else dxpref2="Q";
		end;
		else if dx10code2 eq "N179" then do;
			if count le int(0.5245901639*dx10code2count) then dxpref2="C";
			else if count gt int(0.5245901639*dx10code2count) and count le int(0.868852459*dx10code2count) then dxpref2="6";
			else if count gt int(0.868852459*dx10code2count) and count le int(0.9508196721*dx10code2count) then dxpref2="Q";
			else dxpref2="5";
		end;
		else if dx10code2 eq "N189" then dxpref2="Q";
		else if dx10code2 eq "N390" then do;
			if count le int(0.5808823529*dx10code2count) then dxpref2="Q";
			else if count gt int(0.5808823529*dx10code2count) and count le int(0.7867647059*dx10code2count) then dxpref2="6";
			else if count gt int(0.7867647059*dx10code2count) and count le int(0.9779411765*dx10code2count) then dxpref2="C";
			else dxpref2="5";
		end;
		else if dx10code2 eq "O24801" then dxpref2="Q";
		else if dx10code2 eq "O42021" then do;
			if count le int(0.83333*dx10code2count) then dxpref2="Q";
			else dxpref2="I";
		end;
		else if dx10code2 eq "O48001" then dxpref2="I";
		else if dx10code2 eq "O62301" then dxpref2="Q";
		else if dx10code2 eq "O68101" then dxpref2="Q";
		else if dx10code2 eq "O70001" then dxpref2="Q";
		else if dx10code2 eq "P0599" then do;
			if count le int(0.50*dx10code2count) then dxpref2="P";
			else dxpref2="Q";
		end;
		else if dx10code2 eq "P073" then dxpref2="Q";
		else if dx10code2 eq "P081" then dxpref2="Q";
		else if dx10code2 eq "P599" then dxpref2="Q";
		else if dx10code2 eq "Q381" then dxpref2="Q";
		else if dx10code2 eq "R9431" then dxpref2="Q";
		else if dx10code2 eq "S72080" then do;
			if count le int(0.50*dx10code2count) then dxpref2="C";
			else if count gt int(0.50*dx10code2count) and count le int(0.75*dx10code2count) then dxpref2="5";
			else dxpref2="Q";
		end;
		else if dx10code2 eq "Z2238" then do;
			if count le int(0.50*dx10code2count) then dxpref2="I";
			else dxpref2="Q";
		end;
		else if dx10code2 eq "Z352" then dxpref2="I";
		else if dx10code2 eq "Z3580" then dxpref2="I";
		else if dx10code2 eq "Z37000" then dxpref2="I";
		else if dx10code2 eq "Z850" then dxpref2="C";
	run;

	data hospitalization;
		set intermediate (drop=dx10code2count count);
	run;
%mend createDXpref2;



/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Creating dxtype2 variable*/
%macro createDXType2;
	data hospitalization;
		length dxtype2 $1;
		set hospitalization;
	run;

	proc sql noprint;
		create table temp as
		select *,count(dx10code2) as dx10code2count from hospitalization group by dx10code2;
	quit;

	proc sort data=temp;
		by dx10code2;
	run;

	data intermediate;
		set temp;
		by dx10code2;

		if first.dx10code2 then do;
			count=1;
			retain count;
		end;
		else do;
			count=count+1;
		end;

		if dx10code2 eq "A419" then do;
			if count le int(0.7634133878*dx10code2count) then dxtype2="1";
			else if count gt int(0.7634133878*dx10code2count) and count le int(0.901890649*dx10code2count) then dxtype2="3";
			else if count gt int(0.901890649*dx10code2count) and count le int(0.9611650485*dx10code2count) then dxtype2="2";
			else if count gt int(0.9611650485*dx10code2count) and count le int(0.9816044967*dx10code2count) then dxtype2="W";
			else if count gt int(0.9816044967*dx10code2count) and count le int(0.9994890138*dx10code2count) then dxtype2="5";
			else dxtype2="0";
		end;
		else if dx10code2 eq "B961" then dxtype2="3";
		else if dx10code2 eq "B962" then do;
			if count le int(0.9996062217*dx10code2count) then dxtype2="3";
			else dxtype2="0";
		end;
		else if dx10code2 eq "B965" then dxtype2="3";
		else if dx10code2 eq "B9681" then do;
			if count le int(0.9989047098*dx10code2count) then dxtype2="3";
			else dxtype2="0";
		end;
		else if dx10code2 eq "C3499" then do;
			if count le int(0.7509062662*dx10code2count) then dxtype2="3";
			else if count gt int(0.7509062662*dx10code2count) and count le int(0.990678405*dx10code2count) then dxtype2="1";
			else if count gt int(0.990678405*dx10code2count) and count le int(0.9984464008*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "C679" then do;
			if count le int(0.6943620178*dx10code2count) then dxtype2="3";
			else if count gt int(0.6943620178*dx10code2count) and count le int(0.9821958457*dx10code2count) then dxtype2="1";
			else if count gt int(0.9821958457*dx10code2count) and count le int(0.9910979229*dx10code2count) then dxtype2="5";
			else dxtype2="W";
		end;
		else if dx10code2 eq "D649" then do;
			if count le int(0.7395537525*dx10code2count) then dxtype2="1";
			else if count gt int(0.7395537525*dx10code2count) and count le int(0.8787018256*dx10code2count) then dxtype2="2";
			else if count gt int(0.8787018256*dx10code2count) and count le int(0.9967545639*dx10code2count) then dxtype2="3";
			else if count gt int(0.9967545639*dx10code2count) and count le int(0.9993914807*dx10code2count) then dxtype2="5";
			else dxtype2="W";
		end;
		else if dx10code2 eq "E1128" then do;
			if count le int(0.7782340862*dx10code2count) then dxtype2="3";
			else if count gt int(0.7782340862*dx10code2count) and count le int(0.999486653*dx10code2count) then dxtype2="1";
			else dxtype2="W";
		end;
		else if dx10code2 eq "E1152" then do;
			if count le int(0.8806909913*dx10code2count) then dxtype2="3";
			else if count gt int(0.8806909913*dx10code2count) and count le int(0.9999192767*dx10code2count) then dxtype2="1";
			else dxtype2="W";
		end;
		else if dx10code2 eq "E119" then do;
			if count le int(0.9223505541*dx10code2count) then dxtype2="3";
			else dxtype2="1";
		end;
		else if dx10code2 eq "E860" then do;
			if count le int(0.9770966272*dx10code2count) then dxtype2="1";
			else if count gt int(0.9770966272*dx10code2count) and count le int(0.9923655424*dx10code2count) then dxtype2="2";
			else if count gt int(0.9923655424*dx10code2count) and count le int(0.9971513218*dx10code2count) then dxtype2="3";
			else if count gt int(0.9971513218*dx10code2count) and count le int(0.9987465816*dx10code2count) then dxtype2="5";
			else dxtype2="W";
		end;
		else if dx10code2 eq "E875" then do;
			if count le int(0.9086918349*dx10code2count) then dxtype2="1";
			else if count gt int(0.9086918349*dx10code2count) and count le int(0.9701492537*dx10code2count) then dxtype2="2";
			else if count gt int(0.9701492537*dx10code2count) and count le int(0.9982440738*dx10code2count) then dxtype2="3";
			else dxtype2="W";
		end;
		else if dx10code2 eq "G4730" then do;
			if count le int(0.5577492596*dx10code2count) then dxtype2="3";
			else if count gt int(0.5577492596*dx10code2count) and count le int(0.9957222771*dx10code2count) then dxtype2="1";
			else if count gt int(0.9957222771*dx10code2count) and count le int(0.9980256663*dx10code2count) then dxtype2="W";
			else if count gt int(0.9980256663*dx10code2count) and count le int(0.9996709444*dx10code2count) then dxtype2="2";
			else dxtype2="5";
		end;
		else if dx10code2 eq "I100" then do;
			if count le int(0.7583118216*dx10code2count) then dxtype2="3";
			else if count gt int(0.7583118216*dx10code2count) and count le int(0.9996267844*dx10code2count) then dxtype2="1";
			else if count gt int(0.9996267844*dx10code2count) and count le int(0.9998444935*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "I200" then do;
			if count le int(0.7006369427*dx10code2count) then dxtype2="1";
			else if count gt int(0.7006369427*dx10code2count) and count le int(0.927388535*dx10code2count) then dxtype2="3";
			else if count gt int(0.927388535*dx10code2count) and count le int(0.972611465*dx10code2count) then dxtype2="W";
			else if count gt int(0.972611465*dx10code2count) and count le int(0.9878980892*dx10code2count) then dxtype2="5";
			else dxtype2="2";
		end;
		else if dx10code2 eq "I2088" then do;
			if count le int(0.4963592233*dx10code2count) then dxtype2="3";
			else if count gt int(0.4963592233*dx10code2count) and count le int(0.9514563107*dx10code2count) then dxtype2="1";
			else if count gt int(0.9514563107*dx10code2count) and count le int(0.979368932*dx10code2count) then dxtype2="2";
			else if count gt int(0.979368932*dx10code2count) and count le int(0.9963592233*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "I214" then do;
			if count le int(0.8202217529*dx10code2count) then dxtype2="1";
			else if count gt int(0.8202217529*dx10code2count) and count le int(0.9057550158*dx10code2count) then dxtype2="2";
			else if count gt int(0.9057550158*dx10code2count) and count le int(0.9527455121*dx10code2count) then dxtype2="3";
			else if count gt int(0.9527455121*dx10code2count) and count le int(0.9994720169*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "I2510" then do;
			if count le int(0.606381828*dx10code2count) then dxtype2="1";
			else if count gt int(0.606381828*dx10code2count) and count le int(0.9882098432*dx10code2count) then dxtype2="3";
			else if count gt int(0.9882098432*dx10code2count) and count le int(0.9997836669*dx10code2count) then dxtype2="W";
			else if count gt int(0.9997836669*dx10code2count) and count le int(0.9998918334*dx10code2count) then dxtype2="2";
			else dxtype2="5";
		end;
		else if dx10code2 eq "I4890" then do;
			if count le int(0.6481930366*dx10code2count) then dxtype2="1";
			else if count gt int(0.6481930366*dx10code2count) and count le int(0.9142794183*dx10code2count) then dxtype2="3";
			else if count gt int(0.9142794183*dx10code2count) and count le int(0.9971353019*dx10code2count) then dxtype2="2";
			else if count gt int(0.9971353019*dx10code2count) and count le int(0.9987880123*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "I500" then do;
			if count le int(0.8473259024*dx10code2count) then dxtype2="1";
			else if count gt int(0.8473259024*dx10code2count) and count le int(0.961141221*dx10code2count) then dxtype2="3";
			else if count gt int(0.961141221*dx10code2count) and count le int(0.9887514061*dx10code2count) then dxtype2="2";
			else if count gt int(0.9887514061*dx10code2count) and count le int(0.9965231619*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "J159" then do;
			if count le int(0.9613636364*dx10code2count) then dxtype2="1";
			else if count gt int(0.9613636364*dx10code2count) and count le int(0.9818181818*dx10code2count) then dxtype2="2";
			else dxtype2="3";
		end;
		else if dx10code2 eq "J180" then do;
			if count le int(0.9252232143*dx10code2count) then dxtype2="1";
			else if count gt int(0.9252232143*dx10code2count) and count le int(0.9654017857*dx10code2count) then dxtype2="2";
			else if count gt int(0.9654017857*dx10code2count) and count le int(0.9955357143*dx10code2count) then dxtype2="3";
			else if count gt int(0.9955357143*dx10code2count) and count le int(0.9988839286*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "J181" then do;
			if count le int(0.9292929293*dx10code2count) then dxtype2="1";
			else if count gt int(0.9292929293*dx10code2count) and count le int(0.9656565657*dx10code2count) then dxtype2="3";
			else if count gt int(0.9656565657*dx10code2count) and count le int(0.9939393939*dx10code2count) then dxtype2="2";
			else if count gt int(0.9939393939*dx10code2count) and count le int(0.997979798*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "J189" then do;
			if count le int(0.9251142205*dx10code2count) then dxtype2="1";
			else if count gt int(0.9251142205*dx10code2count) and count le int(0.9601656197*dx10code2count) then dxtype2="3";
			else if count gt int(0.9601656197*dx10code2count) and count le int(0.9917904055*dx10code2count) then dxtype2="2";
			else if count gt int(0.9917904055*dx10code2count) and count le int(0.9962164477*dx10code2count) then dxtype2="5";
			else dxtype2="W";
		end;
		else if dx10code2 eq "J209" then do;
			if count le int(0.9491525424*dx10code2count) then dxtype2="1";
			else if count gt int(0.9491525424*dx10code2count) and count le int(0.9858757062*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "J690" then do;
			if count le int(0.6977753663*dx10code2count) then dxtype2="1";
			else if count gt int(0.6977753663*dx10code2count) and count le int(0.8936516549*dx10code2count) then dxtype2="2";
			else if count gt int(0.8936516549*dx10code2count) and count le int(0.9734129137*dx10code2count) then dxtype2="3";
			else if count gt int(0.9734129137*dx10code2count) and count le int(0.9924036896*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "J90" then do;
			if count le int(0.8673139159*dx10code2count) then dxtype2="1";
			else if count gt int(0.8673139159*dx10code2count) and count le int(0.9401294498*dx10code2count) then dxtype2="3";
			else if count gt int(0.9401294498*dx10code2count) and count le int(0.9943365696*dx10code2count) then dxtype2="2";
			else if count gt int(0.9943365696*dx10code2count) and count le int(0.9975728155*dx10code2count) then dxtype2="5";
			else dxtype2="W";
		end;
		else if dx10code2 eq "K429" then do;
			if count le int(0.9166666667*dx10code2count) then dxtype2="1";
			else if count gt int(0.9166666667*dx10code2count) and count le int(0.9916107383*dx10code2count) then dxtype2="3";
			else dxtype2="0";
		end;
		else if dx10code2 eq "K509" then do;
			if count le int(0.6379853096*dx10code2count) then dxtype2="3";
			else if count gt int(0.6379853096*dx10code2count) and count le int(0.9937040923*dx10code2count) then dxtype2="1";
			else if count gt int(0.9937040923*dx10code2count) and count le int(0.9968520462*dx10code2count) then dxtype2="5";
			else dxtype2="W";
		end;
		else if dx10code2 eq "K8010" then do;
			if count le int(0.68723099*dx10code2count) then dxtype2="3";
			else if count gt int(0.68723099*dx10code2count) and count le int(0.993543759*dx10code2count) then dxtype2="1";
			else if count gt int(0.993543759*dx10code2count) and count le int(0.9992826399*dx10code2count) then dxtype2="W";
			else dxtype2="2";
		end;
		else if dx10code2 eq "K913" then do;
			if count le int(0.9053295933*dx10code2count) then dxtype2="2";
			else if count gt int(0.9053295933*dx10code2count) and count le int(0.9852734923*dx10code2count) then dxtype2="1";
			else if count gt int(0.9852734923*dx10code2count) and count le int(0.9992987377*dx10code2count) then dxtype2="3";
			else dxtype2="W";
		end;
		else if dx10code2 eq "M211" then do;
			if count le int(0.8978805395*dx10code2count) then dxtype2="1";
			else dxtype2="3";
		end;
		else if dx10code2 eq "N179" then do;
			if count le int(0.9242114817*dx10code2count) then dxtype2="1";
			else if count gt int(0.9242114817*dx10code2count) and count le int(0.9697072839*dx10code2count) then dxtype2="2";
			else if count gt int(0.9697072839*dx10code2count) and count le int(0.9969366916*dx10code2count) then dxtype2="3";
			else if count gt int(0.9969366916*dx10code2count) and count le int(0.9990923531*dx10code2count) then dxtype2="W";
			else dxtype2="5";
		end;
		else if dx10code2 eq "N189" then do;
			if count le int(0.6164970541*dx10code2count) then dxtype2="3";
			else if count gt int(0.6164970541*dx10code2count) and count le int(0.9957150509*dx10code2count) then dxtype2="1";
			else if count gt int(0.9957150509*dx10code2count) and count le int(0.9983931441*dx10code2count) then dxtype2="5";
			else if count gt int(0.9983931441*dx10code2count) and count le int(0.9994643814*dx10code2count) then dxtype2="2";
			else dxtype2="W";
		end;
		else if dx10code2 eq "N390" then do;
			if count le int(0.8662811388*dx10code2count) then dxtype2="1";
			else if count gt int(0.8662811388*dx10code2count) and count le int(0.9347864769*dx10code2count) then dxtype2="2";
			else if count gt int(0.9347864769*dx10code2count) and count le int(0.9922597865*dx10code2count) then dxtype2="3";
			else if count gt int(0.9922597865*dx10code2count) and count le int(0.9962633452*dx10code2count) then dxtype2="5";
			else dxtype2="W";
		end;
		else if dx10code2 eq "O24801"  then do;
			if count le int(0.982689211*dx10code2count) then dxtype2="1";
			else if count gt int(0.982689211*dx10code2count) and count le int(0.999194847*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "O32101" then do;
			if count le int(0.9816901409*dx10code2count) then dxtype2="1";
			else dxtype2="3";
		end;
		else if dx10code2 eq "O42021" then do;
			if count le int(0.99644*dx10code2count) then dxtype2="1";
			else dxtype2="3";
		end;
		else if dx10code2 eq "O48001" then do;
			if count le int(0.990080429*dx10code2count) then dxtype2="1";
			else if count gt int(0.990080429*dx10code2count) and count le int(0.9997319035*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "O62301" then do;
			if count le int(0.9941715237*dx10code2count) then dxtype2="1";
			else if count gt int(0.9941715237*dx10code2count) and count le int(0.9975020816*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "O68001" then do;
			if count le int(0.9863829787*dx10code2count) then dxtype2="1";
			else if count gt int(0.9863829787*dx10code2count) and count le int(0.9965957447*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "O68101" then do;
			if count le int(0.9919168591*dx10code2count) then dxtype2="1";
			else if count gt int(0.9919168591*dx10code2count) and count le int(0.9988452656*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;	
		else if dx10code2 eq "O69801" then do;
			if count le int(0.752734375*dx10code2count) then dxtype2="1";
			else if count gt int(0.752734375*dx10code2count) and count le int(0.999609375*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "O70001" then do;
			if count le int(0.9638554217*dx10code2count) then dxtype2="1";
			else if count gt int(0.9638554217*dx10code2count) and count le int(0.9917383821*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "O70101" then do;
			if count le int(0.9768905674*dx10code2count) then dxtype2="1";
			else if count gt int(0.9768905674*dx10code2count) and count le int(0.9894793634*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "P0599" then do;
			if count le int(0.833460657*dx10code2count) then dxtype2="1";
			else if count gt int(0.833460657*dx10code2count) and count le int(0.9931245225*dx10code2count) then dxtype2="0";
			else if count gt int(0.9931245225*dx10code2count) and count le int(0.9992360581*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "P072" then do;
			if count le int(0.9646924829*dx10code2count) then dxtype2="1";
			else if count gt int(0.9646924829*dx10code2count) and count le int(0.9965831435*dx10code2count) then dxtype2="3";
			else dxtype2="W";
		end;
		else if dx10code2 eq "P073" then do;
			if count le int(0.981342713*dx10code2count) then dxtype2="1";
			else if count gt int(0.981342713*dx10code2count) and count le int(0.9970943569*dx10code2count) then dxtype2="3";
			else if count gt int(0.9970943569*dx10code2count) and count le int(0.9990824285*dx10code2count) then dxtype2="0";
			else dxtype2="W";
		end;
		else if dx10code2 eq "P080" then do;
			if count le int(0.675721562*dx10code2count) then dxtype2="0";
			else if count gt int(0.675721562*dx10code2count) and count le int(0.9932088285*dx10code2count) then dxtype2="1";
			else dxtype2="3";
		end;
		else if dx10code2 eq "P081" then do;
			if count le int(0.7747302158*dx10code2count) then dxtype2="0";
			else if count gt int(0.7747302158*dx10code2count) and count le int(0.9964028777*dx10code2count) then dxtype2="1";
			else if count gt int(0.9964028777*dx10code2count) and count le int(0.9995503597*dx10code2count) then dxtype2="3";
			else dxtype2="W";
		end;
		else if dx10code2 eq "P082" then do;
			if count le int(0.8805336568*dx10code2count) then dxtype2="0";
			else if count gt int(0.8805336568*dx10code2count) and count le int(0.9984839297*dx10code2count) then dxtype2="1";
			else if count gt int(0.9984839297*dx10code2count) and count le int(0.9996967859*dx10code2count) then dxtype2="3";
			else dxtype2="W";
		end;
		else if dx10code2 eq "P599" then do;
			if count le int(0.5575686733*dx10code2count) then dxtype2="1";
			else if count gt int(0.5575686733*dx10code2count) and count le int(0.9661016949*dx10code2count) then dxtype2="0";
			else if count gt int(0.9661016949*dx10code2count) and count le int(0.9894798364*dx10code2count) then dxtype2="3";
			else if count gt int(0.9894798364*dx10code2count) and count le int(0.9982466394*dx10code2count) then dxtype2="2";
			else dxtype2="W";
		end;
		else if dx10code2 eq "Q381" then do;
			if count le int(0.6238670695*dx10code2count) then dxtype2="0";
			else if count gt int(0.6238670695*dx10code2count) and count le int(0.9879154079*dx10code2count) then dxtype2="1";
			else dxtype2="3";
		end;
		else if dx10code2 eq "R9430" then dxtype2="3";
		else if dx10code2 eq "R9431" then dxtype2="3";
		else if dx10code2 eq "S72080" then do;
			if count le int(0.6027777778*dx10code2count) then dxtype2="3";
			else if count gt int(0.6027777778*dx10code2count) and count le int(0.8833333333*dx10code2count) then dxtype2="1";
			else if count gt int(0.8833333333*dx10code2count) and count le int(0.9416666667*dx10code2count) then dxtype2="2";
			else if count gt int(0.9416666667*dx10code2count) and count le int(0.9972222222*dx10code2count) then dxtype2="W";
			else dxtype2="X";
		end;
		else if dx10code2 eq "Z2238" then do;
			if count le int(0.9926925239*dx10code2count) then dxtype2="3";
			else dxtype2="0";
		end;
		else if dx10code2 eq "Z291" then do;
			if count le int(0.6703296703*dx10code2count) then dxtype2="3";
			else if count gt int(0.6703296703*dx10code2count) and count le int(0.8846153846*dx10code2count) then dxtype2="1";
			else dxtype2="0";
		end;
		else if dx10code2 eq "Z292" then do;
			if count le int(0.5660781166*dx10code2count) then dxtype2="1";
			else if count gt int(0.5660781166*dx10code2count) and count le int(0.8929909042*dx10code2count) then dxtype2="3";
			else if count gt int(0.8929909042*dx10code2count) and count le int(0.9973247726*dx10code2count) then dxtype2="0";
			else dxtype2="2";
		end;
		else if dx10code2 eq "Z302" then do;
			if count le int(0.9047399908*dx10code2count) then dxtype2="1";
			else if count gt int(0.9047399908*dx10code2count) and count le int(0.9995398067*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "Z33" then do;
			if count le int(0.8968058968*dx10code2count) then dxtype2="3";
			else if count gt int(0.8968058968*dx10code2count) and count le int(0.9975429975*dx10code2count) then dxtype2="1";
			else dxtype2="W";
		end;
		else if dx10code2 eq "Z352" then do;
			if count le int(0.7010869565*dx10code2count) then dxtype2="3";
			else dxtype2="1";
		end;
		else if dx10code2 eq "Z3580" then do;
			if count le int(0.6060*dx10code2count) then dxtype2="3";
			else dxtype2="1";
		end;
		else if dx10code2 eq "Z37000" then dxtype2="3";
		else if dx10code2 eq "Z38000" then dxtype2="0";
		else if dx10code2 eq "Z38010" then dxtype2="0";
		else if dx10code2 eq "Z412" then do;
			if count le int(0.9446202532*dx10code2count) then dxtype2="0";
			else if count gt int(0.9446202532*dx10code2count) and count le int(0.9976265823*dx10code2count) then dxtype2="1";
			else dxtype2="3";
		end;
		else if dx10code2 eq "Z501" then do;
			if count le int(0.5052484255*dx10code2count) then dxtype2="1";
			else if count gt int(0.5052484255*dx10code2count) and count le int(0.8229531141*dx10code2count) then dxtype2="W";
			else if count gt int(0.8229531141*dx10code2count) and count le int(0.9986004199*dx10code2count) then dxtype2="3";
			else dxtype2="2";
		end;
		else if dx10code2 eq "Z850" then dxtype2="3";
		else if dx10code2 eq "Z9661" then do;
			if count le int(0.9987261147*dx10code2count) then dxtype2="3";
			else dxtype2="1";
		end;
	run;

	data hospitalization;
		set intermediate (drop=dx10code2count count);
	run;
%mend createDXType2;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce blank pat_id and invalid pat_id in dataset*/
%macro patid_errors;
	proc sql noprint;
		create table subset_1 as
		select * from hospitalization group by pat_id having count(pat_id) eq 1;
		create table subset_2 as
		select * from hospitalization group by pat_id having count(pat_id) gt 1;
	quit;

	%retrieveObs (interds=subset_1)

	%let nsample=%sysfunc(int(%sysevalf(0.1545*&internobs)));
	proc surveyselect data=subset_1 out=subset_1a method=srs sampsize=&nsample seed=7654321;
	run;

	proc sql noprint;
		create table subset_1b as
		select * from subset_1 where key not in (select distinct key from subset_1a);
	quit;


	%retrieveObs (interds=subset_1a)
	data subset_1aa subset_1ab;
		set subset_1a;
		if _n_ le (.65*&internobs) then  output subset_1aa;
		else output subset_1ab;
	run;

	data subset_1aa;
		set subset_1aa;
		call missing(pat_id);
		call missing(linkage_type);
		pat_idtype="B";
	run;

	data subset_1ab;
		set subset_1ab;
		call missing(linkage_type);
		pat_idtype="I";
	run;

	data subset_1a;
		set subset_1aa subset_1ab;
	run;

	data subset_1;
		set subset_1a subset_1b;
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;
%mend patid_errors;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce unique when not missing condition*/
%macro chart_num_errors;
	%retrieveObs (interds=hospitalization);
	%let nsample=%sysfunc(int(%sysevalf(0.20*&internobs)));
	proc surveyselect data=hospitalization out=subset_1 method=srs sampsize=&nsample seed=7654321;
	run;

	proc sql noprint;
		create table subset_2 as
		select * from hospitalization where key not in (select distinct key from subset_1);
	quit;

	data subset_1;
		set subset_1;
		call missing(chart_num);
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;
%mend chart_num_errors;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce invalid code error in dataset*/
%macro invalid_code_errors;
	%retrieveObs (interds=hospitalization)

	proc sort data=hospitalization out=temp;
		by descending pat_id ;
	run;

	%let nsample=%sysfunc(int(%sysevalf(0.02*&internobs)));
	proc surveyselect data=temp out=subset_1 method=srs sampsize=&nsample seed=7654321;
	run;

	proc sql noprint;
		create table subset_2 as
		select * from temp where key not in (select distinct key from subset_1);
	quit;

	%retrieveObs (interds=subset_1)
	data subset_1a subset_1b;
		set subset_1;
		if _n_ le (.50*&internobs) then  output subset_1a;
		else output subset_1b;
	run;

	data subset_1a;
		set subset_1a;
		call missing(dx10code2);
		call missing(dxpref2);
		call missing(dxtype2);
	run;

	
	data subset_1b;
		set subset_1b;
		dx10code2="ZXZXZa";
		dxpref2="Z";
	run;

	data subset_1;
		set subset_1a subset_1b;
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;

	proc sort data=hospitalization;
		by key;
	run;
%mend invalid_code_errors;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce date error in dataset*/
%macro date_error_obs_num;
	/*Generate two consecutive  years with same number of observations*/
	%local start_yr min_yr min_count max_yr max_count yr prev_yr mod_years inter_yr;
	data temp;
		set hospitalization;
		yr=year(ddate);
	run;

	proc freq data=temp noprint;
		table yr/out=intermediate;
	run;

	proc sort data=intermediate;
		by yr;
	run;

	data subset;
		set intermediate end=eof;
		by yr;
		if _n_=1  then do;
			call symput('start_yr',yr);
			delete;
		end;
		else if eof  then delete;
	run;

	data subset;
		set subset;
		diff=abs(count-lag(count));
	run;

	proc sql noprint;
		select distinct yr into: yr from subset having diff= min(diff) and diff is not missing;
	quit;

	proc sql noprint;
		create table subset_1 as
		select * from temp where yr eq &yr or yr eq (&yr-1);
		create table subset_2 as
		select * from temp where yr ne &yr and yr ne (&yr-1);
	quit;

	proc freq data=subset_1 noprint;
		table yr/out=intermediate;
	run;

	proc sql noprint;
		select distinct yr,count into: min_yr, : min_count from intermediate having count= min(count) ;
		select distinct yr,count into: max_yr, : max_count from intermediate having count= max(count) ;
	quit;

	proc sql noprint;
		create table subset_1a as
		select * from subset_1 where yr eq &min_yr;
		create table subset_1b as
		select * from subset_1 where yr eq &max_yr;
	quit;

	data subset_1b changeyr_1b;
		set subset_1b;
		if _n_ le &min_count then do;
			output subset_1b;
		end;
		else output changeyr_1b;
	run;

	data changeyr_1b;
		set changeyr_1b;
		admdate=intnx('year',admdate,(&start_yr-&max_yr),"same");
		admtime=intnx('dtyear',admtime,(&start_yr-&max_yr),"same");
		ddate=intnx('year',ddate,(&start_yr-&max_yr),"same");
		dtime=intnx('dtyear',dtime,(&start_yr-&max_yr),"same");	
	run;

	data hospitalization (drop=yr);
		set subset_1a subset_1b changeyr_1b subset_2 ;
	run;

	%let mod_years=&min_yr &max_yr;

    /*Generate two consecutive fiscal years with same number of observations*/
	data temp;
		set hospitalization;
		fiscalyr=strip(put(intnx('year.4',ddate,0,'B'),year4.))||"/"||strip(put(intnx('year.4',ddate,0,'E'),year4.));
		yr=year(ddate);
		prev_fiscalyr=strip(put(intnx('year.4',intnx('year',ddate,-1,"same"),0,'B'),year4.))||"/"||strip(put(intnx('year.4',intnx('year',ddate,-1,"same"),0,'E'),year4.));
	run;

	proc sql noprint;
		create table subset_1 as
		select * from temp where yr in (&mod_years);
		create table subset_2 as
		select * from temp where yr not in (&mod_years);
	quit;

	proc freq data=subset_2 noprint;
		table fiscalyr/out=intermediate;
	run;

	proc sql noprint;
		create table subset as
		select a.*,b.prev_fiscalyr from intermediate as a, temp as b where a.fiscalyr eq b.fiscalyr;
	quit;

	proc sort data=subset out=temp nodupkey;
		by _all_;
	run;

	data intermediate;
		set temp;
	run;

	proc sort data=intermediate;
		by fiscalyr;
	run;

	data subset;
		set intermediate end=eof;
		by fiscalyr;
		if _n_=1  then delete;
		else if eof  then delete;
	run;

	data subset;
		set subset;
		diff=abs(count-lag(count));
	run;

	proc sql noprint;
		select distinct fiscalyr,prev_fiscalyr into: yr, :prev_yr from subset having diff= min(diff) and diff is not missing;
	quit;

	proc sql noprint;
		create table subset_2a as
		select * from subset_2 where fiscalyr eq "&yr" or fiscalyr eq "&prev_yr";
		create table subset_2b as
		select * from subset_2 where fiscalyr ne "&yr" and fiscalyr ne "&prev_yr";
	quit;

	proc freq data=subset_2a noprint;
		table fiscalyr/out=intermediate;
	run;

	proc sql noprint;
		select distinct fiscalyr,count into: min_yr, : min_count from intermediate having count= min(count) ;
		select distinct fiscalyr,count into: max_yr, : max_count from intermediate having count= max(count) ;
	quit;

	proc sql noprint;
		create table subset_2aa as
		select * from subset_2a where fiscalyr eq "&min_yr";
		create table subset_2ab as
		select * from subset_2a where fiscalyr eq "&max_yr";
	quit;

	data subset_2ab changeyr_2ab;
		set subset_2ab;

		if _n_=1 then call symput('max_yr',yr);

		if _n_ le &min_count then do;
			output subset_2ab;
		end;
		else output changeyr_2ab;
	run;

	proc sql noprint;
		select distinct yr into: inter_yr separated by " " from changeyr_2ab;
	quit;

	data changeyr_2ab;
		set changeyr_2ab;
		admdate=intnx('year',admdate,(&start_yr-&max_yr),"same");
		admtime=intnx('dtyear',admtime,(&start_yr-&max_yr),"same");
		ddate=intnx('year',ddate,(&start_yr-&max_yr),"same");
		dtime=intnx('dtyear',dtime,(&start_yr-&max_yr),"same");	
	run;

	data hospitalization (drop=yr fiscalyr prev_fiscalyr);
		set subset_1 subset_2aa subset_2ab changeyr_2ab subset_2b ;
	run;

	proc sort data=hospitalization;
		by key;
	run;

	%let mod_years=&mod_years &max_yr &inter_yr;

	%date_error_outlier (mod_years=&mod_years,
						 start_yr=&start_yr);
%mend date_error_obs_num;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce date error in dataset*/
%macro date_error_outlier (mod_years=,
						   start_yr=);
	data temp;
		set hospitalization;
		fiscalyr=strip(put(intnx("year.4",ddate,0,"B"),year4.))||"/"||strip(put(intnx("year.4",ddate,0,"E"),year4.));
		yr=year(ddate);
	run;

	proc freq data=temp noprint;
		table fiscalyr/out=intermediate;
	run;

	proc sql noprint;
		create table subset as
		select *,int(mean(count)) as avg, (count-calculated avg) as diff from intermediate;
	quit;

	proc sql noprint;
		create table intermediate as
		select a.*,b.yr from subset as a, temp as b where a.fiscalyr eq b.fiscalyr;
	quit;

	proc sort data=intermediate out=subset nodupkey;
		by _all_;
	run;

	data subset;
		set subset;
		where yr not in (&mod_years);
	run;

	proc sort data=subset;
		by fiscalyr;
	run;

	%retrieveObs (interds=subset)
	data subset;
		set subset;
		by fiscalyr;
		if _n_ gt 2 and _n_ le &internobs-4 then output;
	run;
	
	proc sql noprint;
		select distinct fiscalyr,count into: max_yr, : max_count from subset having diff= max(diff) ;
	quit;

	proc sql noprint;
		create table subset_1 as
		select * from temp where yr not in (&mod_years);
		create table subset_2 as
		select * from temp where yr  in (&mod_years);
	quit;

	proc sql noprint;
		create table subset_1a as
		select * from subset_1 where  fiscalyr eq "&max_yr" or yr eq &start_yr;
		create table subset_1b as
		select * from subset_1 where  fiscalyr ne "&max_yr" and yr ne &start_yr;
	quit;

	proc sql noprint;
		create table subset_1aa as
		select *,month(ddate) as month from subset_1a where  yr eq &start_yr;
		create table subset_1ab as
		select *,month(ddate) as month from subset_1a where  yr ne &start_yr;
	quit;
	
	data subset_1aa_a subset_1aa_b;
		set subset_1aa;
		if month le 3 then output subset_1aa_a;
		else output subset_1aa_b;
	run;
		
	%retrieveObs (interds=subset_1aa_b)
	data subset_1aa_b changeyr_1aa_b;
		set subset_1aa_b;
		if _n_ le (0.75*&internobs) then output changeyr_1aa_b;
		else output subset_1aa_b;
	run;

	proc sql noprint;
		select distinct yr into: to_yr from subset_1ab where month ge 4 ;
	quit;
	
	data changeyr_1aa_b;
		set changeyr_1aa_b;
		admdate=intnx("year",admdate,(&to_yr.- yr),"same");
		admtime=intnx("dtyear",admtime,(&to_yr.- yr),"same");
		ddate=intnx("year",ddate,(&to_yr.- yr),"same");
		dtime=intnx("dtyear",dtime,(&to_yr.- yr),"same");	
	run;

	data hospitalization (drop=yr fiscalyr month);
		set changeyr_1aa_b subset_1aa_b subset_1aa_a subset_1ab subset_1b subset_2;
	run;

%mend date_error_outlier;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce unique when not missing condition*/
%macro missing_datetime_var;
	%retrieveObs (interds=hospitalization);
	%let nsample=%sysfunc(int(%sysevalf(0.37*&internobs)));
	proc surveyselect data=hospitalization out=subset_1 method=srs sampsize=&nsample seed=7654321;
	run;

	proc sql noprint;
		create table subset_2 as
		select * from hospitalization where key not in (select distinct key from subset_1);
	quit;

	data subset_1;
		set subset_1;
		call missing(admtime);
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;

	%let nsample=%sysfunc(int(%sysevalf(0.23*&internobs)));
	proc surveyselect data=hospitalization out=subset_1 method=srs sampsize=&nsample seed=7654321;
	run;

	proc sql noprint;
		create table subset_2 as
		select * from hospitalization where key not in (select distinct key from subset_1);
	quit;

	data subset_1;
		set subset_1;
		call missing(dtime);
	run;

	data hospitalization;
		set subset_1 subset_2;
	run;
%mend missing_datetime_var;

/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce erros in the variable birthdate */
%macro birthdate_errors;
	%retrieveObs (interds=hospitalization);
    
	%let nsample=%sysfunc(int(%sysevalf(0.0022*&internobs)));
	proc surveyselect data=hospitalization out=subset_1 method=srs sampsize=&nsample. seed=56983;
	run;

  %let nsample=%sysfunc(int(%sysevalf(0.0003*&internobs)));
  proc surveyselect data=hospitalization out=subset_2 method=srs sampsize=&nsample. seed=45893;
	run;

  %let nsample=%sysfunc(int(%sysevalf(0.0003*&internobs)));
  proc surveyselect data=hospitalization out=subset_3 method=srs sampsize=&nsample. seed=698325;
	run;

  %let nsample=%sysfunc(int(%sysevalf(0.0006*&internobs)));
  proc surveyselect data=hospitalization out=subset_4 method=srs sampsize=&nsample. seed=25768;
	run;

  %let nsample=%sysfunc(int(%sysevalf(0.0011*&internobs)));
  proc surveyselect data=hospitalization out=subset_5 method=srs sampsize=&nsample. seed=3996522;
	run;

  %let nsample=%sysfunc(int(%sysevalf(0.0011*&internobs)));
  proc surveyselect data=hospitalization out=subset_6 method=srs sampsize=&nsample. seed=12832269;
	run;


  %let nsample=%sysfunc(int(%sysevalf(0.003*&internobs)));
  proc surveyselect data=hospitalization(where=(1950 < year(birthdate) <= 1960))
                    out=subset_7 method=srs sampsize=&nsample. seed=754777;
	run;


  proc sql noprint;
		create table subset_8 as
		select * 
    from hospitalization 
    where 
      key not in (select distinct key from subset_1) and
      key not in (select distinct key from subset_2) and
      key not in (select distinct key from subset_3) and
      key not in (select distinct key from subset_4) and
      key not in (select distinct key from subset_5) and
      key not in (select distinct key from subset_6) and
      key not in (select distinct key from subset_7) 
    ;
	quit;

  /* introduce missing birthdate*/
  data subset_1;
		set subset_1;
    call missing(birthdate);
	run;

  /* introduce birthdate errors: +1 and -1*/
  data subset_2;
		set subset_2;
    birthdate = birthdate + 1;
	run;

  data subset_3;
		set subset_3;
    birthdate = birthdate - 1;
	run;

  /* introduce birthdate errors: +(1, 10) and (-1, 10)*/
  data subset_4;
		set subset_4;
    seed = 1e3 * mod(round(1e3 * datetime()), 1e6) + 1;
    birthdate = birthdate +int(rannorm(seed)* 10 + 1);
    drop 
      seed
    ;
	run;

  /* introduce birthdate errors: +[11, 365) and (-365, -11]*/
  data subset_5;
		set subset_5;
    seed = 1e3 * mod(round(1e3 * datetime()), 1e6) + 1;
    birthdate = birthdate + int(rannorm(seed)* 365 + 10);
    drop 
      seed
    ;
	run;

  /* introduce birthdate errors: >+365 and <-365*/
  data subset_6;
		set subset_6;
    seed = 1e3 * mod(round(1e3 * datetime()), 1e6) + 1;
    birthdate = birthdate + int(rannorm(seed)* 365 * 10 + 365);
    drop 
      seed
    ;
	run;

  /* introduce the dectectable birthdate errors for birth year between (1950, 1960]*/
  data subset_7;
		set subset_7;
    seed = 1e3 * mod(round(1e3 * datetime()), 1e6) + 1;
    birthdate = birthdate + abs(int(rannorm(seed)* 365 * 10 + 365 * 5));
    drop 
      seed
    ;
	run;

	data hospitalization;
		set subset_1 subset_2 subset_3 subset_4 subset_5 subset_6 subset_7 subset_8;
	run;


  proc datasets lib=work memtype=data nodetails nolist;
    delete subset_1 subset_2 subset_3 subset_4 subset_5 subset_6 subset_7 subset_8;
  run;
  
%mend birthdate_errors;
/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to introduce erros in the variable sex */
%macro sex_errors;
	%retrieveObs (interds=hospitalization);
	%let nsample=%sysfunc(int(%sysevalf(0.02*&internobs)));
  
	proc surveyselect data=hospitalization out=subset_1 method=srs sampsize=&nsample. seed=52565;
	run;

	%let nsample=%sysfunc(int(%sysevalf(0.005*&internobs)));
	proc surveyselect data=hospitalization out=subset_2 method=srs sampsize=&nsample. seed=21014;
	run;

	proc sql noprint;
		create table subset_3 as
		select * from hospitalization where key not in (select distinct key from subset_1) and key not in (select distinct key from subset_2);
	quit;

	data subset_1;
		set subset_1;
		if sex ='M' then sex = 'F';
    if sex ='F' then sex = 'M'; 
	run;

	data subset_2;
		set subset_2;
    call missing(sex);
	run;

	data hospitalization;
		set subset_1 subset_2 subset_3;
	run;
  
%mend sex_errors;

/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to initiate the process of introducing errors/inconsistency in dataset*/
%macro introduce_errors;
	%patid_errors
	%chart_num_errors
	%invalid_code_errors
	%date_error_obs_num
	%missing_datetime_var
  /* Added by Sean on May 14, 2018*/
  %birthdate_errors
  %sex_errors
  /* Added end */
%mend introduce_errors;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Deleting all intermediate temporary datasets*/
%macro deleteTempDs;
	proc datasets lib=work;
		delete  changeyr_1aa_b changeyr_1b changeyr_2ab
				subset
				subset_1 subset_2 subset_3
				subset_1a subset_1b subset_1b_1 subset_1b_2 subset_1_temp subset_1b_a  subset_1b_b subset_1b_ba  subset_1b_bb
				subset_1aa subset_1aa_a subset_1aa_b subset_1ab
				subset_2a subset_2b subset_2a_1 subset_2a_2 subset_2b_1 subset_2b_2 subset_2aa subset_2ab 
				subset_2a_temp subset_2_temp subset_2_1a subset_2_2b_temp subset_2_1 subset_2_2 subset_2_2a subset_2_2b
                unique_patid_1 unique_patid_2 unique_patid unique_patid 
				temp intermediate
				;
	run;
%mend deleteTempDs;


/*-----------------------------------------------------------------------------------------------------------------------------*/
/*-----------------------------------------------------------------------------------------------------------------------------*/
/*Macro to initiate generation of dummy datasets*/
%macro createSimulatedData (nobs=,
						endyr=,
						noyrs=);

	%initialize_checks (nobs=&nobs,
						endyr=&endyr,
						noyrs=&noyrs);

	%global internobs;
	%createPatId (nobs=&nobs)
	%createKey
	%createChartNum
	%createAgeVar (nobs=&nobs,
				   endyr=&endyr)
	%createAgeCat
	%createAgeCode (nobs=&nobs)
	%createDateVar (nobs=&nobs,
				    endyr=&endyr,
					noyrs=&noyrs)
  /* added by Sean on May 11, 2018 */
  %createBirthDateVar
  /* added end */

	%createLOSVar
	%createInstType (nobs=&nobs)
	%createGender
  /* added by Sean on May 11, 2018 */
  %createReferenceData(out = ReferenceData)
  /* added end */
	%createLinkageType
	%createDX10code1
	%createDXpref1 
	%createDXType1 
	%createDX10code2
	%createDXpref2
	%createDXType2


	%introduce_errors /* introduce birth date error here */
 
	%deleteTempDs

	data hospitalization (label="Simulated data for demonstration");
		retain key pat_id pat_idtype linkage_type sex age agecat agecode ageunit admdate admtime ddate dtime chart_num acutelos 
			   insttype dx10code1 dx10code2 dxpref1 dxpref2 dxtype1 dxtype2;
		set hospitalization;
		label key           = "Key - unique record identifier"
			  chart_num     = "Patient chart number"
			  pat_id        = "Patient identification number"
			  pat_idtype    = "Valid/Invalid patient key number/identifier"
			  linkage_type  = "Type of linkage (Determinstic/Probablistic)"
        sex           = "Gender"
        age           = "Age in years"
        agecat        = "Age category"
        agecode       = "Age code"
        ageunit       = "Age unit"
        admdate       = "Admission date"
        admtime       = "Admission time"
        birthdate     = "Date of birth"
        ddate         = "Discharge date"
        dtime         = "Discharge time"
        acutelos      = "Acute length of stay"
			  insttype      = "Type of institution"
        dx10code1     = "Diagnosis code 1"
			  dx10code2     = "Diagnosis code 2"
        dxpref1	      = "Main problem prefix"
			  dxpref2	      = "Other problem prefix 2"
			  dxtype1       = "Main diagnosis type 1"	
			  dxtype2       = "Other diagnosis type 2";	
	run;

	proc sort data=hospitalization;
		by key;
	run;

	%symdel internobs;
%mend createSimulatedData;

/******************************************************************************************************************************
 ******************************************************************************************************************************/


