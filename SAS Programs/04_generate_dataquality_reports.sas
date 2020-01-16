/*========================================================================  
DataFit Toolkit - Program for generating data quality reports
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

/**************************************************************************************/
 *
 * 				(1) Setup
 *
 * Setup DataFit Toolkit
/**************************************************************************************/;

%inc 'S:\DQIM\DataFit Toolkit\Macros\*.sas';

options mprint DKRICOND=WARN;

/**************************************************************************************/
 *
 * 				(2) Create Metadata
 *
 * Define the physical location of "VARLIST" file in the PATH=
/**************************************************************************************/;

%meta (lib =WORK,
       ds= hospitalization,
       path='S:\DQIM\DataFit Toolkit\Varlists\hospitalization_varlist.txt',
       outlib=WORK
       );

data metadata;
    set meta_hospitalization;
run;

/**************************************************************************************/
 *
 * 				(3) Create VIMO Report
 *
 * Define a physical location to save the report in the PATH=
 * Make sure you have already created a subfolder under the PATH as "Freq"
 * Define a physical location to "Scripts" folder in the scriptsWINpath=
/**************************************************************************************/;

%vimo( ds=WORK.hospitalization,
       path=S:\DQIM\DataFit Toolkit\DQ Reports,
       metalib=WORK,
	   FMTLIB=WORK,
       id= key pat_id chart_num,
	   scriptsWINpath=S:\DQIM\DataFit Toolkit\scripts\
       );

/**************************************************************************************/
 *
 * 				(4) Create Linkability Report
 *
 * Define a physical location to save the report in the PATH=
/**************************************************************************************/;


%linkability( ds=WORK.hospitalization,
              bydate=ddate,
			  linktype=linkage_type,
              linktypefmt=$Hosp_link_type.,
              startyr=2005,
              endyr=2014,
			  time=fiscal,
		      FMTLIB=WORK,
              path=S:\DQIM\DataFit Toolkit\DQ Reports
             );


/**************************************************************************************/
 *
 * 				(5) Create Trend Report
 *
 * Define a physical location to save the report in the PATH=
/**************************************************************************************/;


%trend( ds=WORK.hospitalization,
        startyr=2005,
        endyr=2014,
        bydate=ddate,
		time=fiscal,
        path=S:\DQIM\DataFit Toolkit\DQ Reports
        );


/**************************************************************************************/
 *
 * 				(6) Create TIM Report
 *
 * Define a physical location to save the report in the PATH=
/**************************************************************************************/;


%TIM (library=WORK,
	  data=hospitalization,
	  start=2005,
	  end=2014,
	  refdate=ddate,
	  path=S:\DQIM\DataFit Toolkit\DQ Reports
	 );


/**************************************************************************************/
 *
 * 				(7) Create AGREEMENT Report
 *
 * Define a physical location to save the report in the PATH=
/**************************************************************************************/;
%agreement(
     lib          = work
	,templib      = work
	,ds           = hospitalization
	,ds_prefix    = off
	,ds_startyr   = 2005
	,ds_endyr     = 2014
	,ds_byvar     = pat_id
	,ds_bydate    = admdate
	,ds_datevar   = birthdate
	,ds_categvar  = sex
	,ref_data     = work.referencedata
	,ref_byvar    = pat_id
	,ref_datevar  = birthdate
	,ref_categvar = sex
	,time         = fiscal
	,path         = S:\DQIM\DataFit Toolkit\DQ Reports
);


/**************************************************************************************/
 *
 * 				(8) Create Data Dictionary
 *
 * Define a physical location to save the Data Dictionary in the PATH=
 * Make sure you have already created two subfolders under the PATH as "Lookup" and "Variables"
/**************************************************************************************/;


%dictionary(  libname      = work,
		      dataset      = hospitalization,
		      metadata     = work.metadata,
		      fmtlib       = work,
		      path         = S:\DQIM\DataFit Toolkit\DQ Reports,
		      lookupsubdir = Lookup,
		      varsubdir    = Variables,
		      shownvalue   = 20,
		      title        = The Data Dictionary for Hospitalization data
		    );
