/*========================================================================  
DataFit Toolkit - DQLite macro
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

/*__________________________________________________________________________________
  | MACRO:       DQLite
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        December 2015
  |
  | DESCRIPTION: Performs a "lite" data quality assessments for any cohort created out of any combination of 
  |              ICES Data Repository for users who are not trained on data quality process.
  |              This macro generates VIMO, TIM, Trend and Linkability reports. 
  |
  | PARAMETERS:  
  |  - Mandatory PARAMETERS:  
  |
  |              COHORT      = Name of dataset (cohort). Could be one or two-level SAS name (eg. LIBRARY.DATASET)
  |
  |              PATH        = Location for saving the reports
  |
  |  - Optional PARAMETERS:
  |
  |              TIME        = Time scale (fiscal|calendar|quarterly|monthly)- (Default is Fiscal)
  |
  |              STARTYYYY   = four-digit start year (Required for TIM, TREND and LINKABILITY)
  |                       
  |              ENDYYYY     = four-digit end year (Required for TIM, TREND and LINKABILITY)
  |
  |              DATEVAR     = Name of a SAS date variable for DQ reports over time 
  |                            (Required for TIM, TREND and LINKABILITY)
  |
  |              BYVAR       = Optional categorical variable. If provided, the trend grapg will be generated for
  |                            each level of this variable
  |                    
  |              LINKTYPE    = The variable which contains type of linkage (for ICES data it's usually VALIKN or LINK_TYPE)
  |                            (Required for LINKABILITY)
  |
  |              LINKTYPEFMT = The format of LINKTYPE variable (for ICES data it's usually $VALIKN. or $LINK_TYPE.)
  |                            (Required for LINKABILITY)
  |
  |              DICTIONARY  = ON/OFF. ON  - Generate the Data Dictionary (a HTML file and two folders-Lookup 
  |                                          and Variables) for the cohort.
  |                                    OFF - Do not generate the Data Dictionary (a HTML file and two folders-
  |                                          Lookup and Variables) for the cohort.
  |
  |
  | EXAMPLE:     
  |              %dqlite(
  |                cohort      = mycohort ,
  |                path        = /users/mazimaee/Temp/DQLite,
  |                time        = calendar,
  |                startyyyy   = 2005,
  |                endyyyy     = 2010,
  |                datevar     = dthdate, 
  |                byvar       = FEDUC,
  |                linktype    = link_type, 
  |                linktypefmt = $link_type.,
  |                dictionary  = ON
  |              )
  |
  |              %dqlite(
  |                cohort = mycohort ,
  |                path   = /users/mazimaee/Temp/DQLite
  |              );
  |               
  |              %dqlite(
  |                cohort    = mycohort ,
  |                path      = /users/mazimaee/Temp/DQLite,
  |                time      = calendar,
  |                startyyyy = 2005,
  |                endyyyy   = 2010,
  |                datevar   = dthdate
  |              )          
  |               
  | UPDATE:     
  |            May 2016, Sean Ji
  |            - Added the parameter "dictionary" and let this macro call 
  |              %DICTIONARY to create the data dictinary web pages for   
  |              the specified dataset when dictionary = ON.
  |            - Added the parameter "offline", which corresponding the
  |              same parameter "offline" in %VIMO
  |       
  |            Nov 2016, Mahmoud Azimaee
  |            - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/

%macro dqlite(
  cohort      = ,
  path        = ,
  time        = fiscal,
  startyyyy   = ,
  endyyyy     = ,
  datevar     = , 
  byvar       = ,
  linktype    = , 
  linktypefmt = ,
  dictionary  = OFF,
  scriptsWINpath=https://inside.ices.on.ca/dataprog/scripts/
);

  **************************;
  *** Initialization     ***;
  **************************;
  systask command "mkdir -p /&path" wait;

  /* check parameter */
  %local _datevar; /* &datevar has been used im %VIMO*/
  %let _datevar = &datevar;

  %let dictionary = %upcase(&dictionary);

  /* Single level data set name */
  %if %index(&cohort,.) = 0 %then %do;
    %let library = work;
    %let dataset = %upcase(&cohort);
  %end;

  /* Two level data set name */
  %else %do;
    %let library = %upcase(%scan(&cohort,1,'.'));
    %let dataset = %upcase(%scan(&cohort,2,'.'));
  %end;

  /* Pre-assign all possible ID variables for ICES data repository */ 
  %let dqliteid = IKN ID A6_ENC A6B AA3 ACTIVE_ID ADMISSION_ID ADMITMD_MDNUM AGENT_ID AMBCNO ANNUALID APP_ID ASSESS ASSESSMENT_ID_CA
  ASSESSMENT_ID_ENC ASSESSMENT_ID_HC ATTENDMD_MDNUM B_IKN B_KEY BMT_ID CANCER_ID CARE_AUTH_ID
  CASE_ID_ENC CASE_KEY_ENC CCRSKEY CHEMO_ID CICKEY CIHIKEY CLAIM_NUM_ENC CLIENT_ID_ENC CLIENTID_ENC
  CLINIC_NUMBER CMSM COMMUNITY_CENTRE_ID COMPLAINT_ID CREATEUSERID DADKEY DEATH_ID DIAGNOSIS_ID
  DIN DISEASE_ID DONOR_ID ENCOUNT ENCOUNTER_ID_ENC ENCPSO EPI EPI_ID EVENT_ID FACILITY_ID
  FACILITY_NUM FEVER_ID FROM_ID HEIGHT_ID HIV_ID HOBICID_ENC IDS_CLIENTID_ENC IKNCORR
  IKNDAD IKNRECOVERED INITIAL_FACILITY_NUM  INST INSULIN_KEY KEY LINKEDKEY LINKID LONG_ID
  M_IKN M_KEY MARKER_ID MDNUM1 MEDICATION_ID MINIMAL_ID MSGID_ENC NACRSKEY OMHRSKEY OMHRSKEY_ADM
  ORG ORGAN_ID ORGDKEY OTHER_ID OTR_CDS_FACILITY_CARE_ID OTRCDSKEY PALLIATIVE_ID PATH_INT_KEY_ENC
  PATH_REPORT_KEY_ENC PATID PATIENT_ID PATIENT_ID_ENC PATIENTID PCC_CLIENT_ID_ENC PERSON_KEY_ENC
  PHYSNUM PHYSNUM2 PLAN_ID POGO_CODE PRCD PRCDCSD PRCDDA PRCMACT PRESC_I PROGRAM_ID PRVNUM1
  RADIATION_ID RCS_KEY RECIPIENT_ID RECIPIENT_TREATMENT_171_ID RECIPIENT_TREATMENT_ID RECORD_ID
  REFERRAL_IDENTIFIER REFPHYS REGISTRATION_NO REGNUM REGNUM2 RELAPSE_ID RESIDENT_CODE 
  RESPIRATORY_KEY REVISED_ID SATELLITE_ID SDSKEY SECONDARY_ID SERIAL SERVICE_IDENTIFIER SHARED_ID
  SUPPORT_ID SYNTHID TO_ID TRANSFER_ID TREATMENT_FACILITY_NUM UPDATEUSERID ;


  **************************;
  *** Generate Metadata  ***;
  **************************;
  %meta(
    lib    = &library,
    ds     = &dataset,
    outlib = work,
    path   = '//sasroot/sastools/macros/DQ/general_varlist.txt'
  )

  proc sort data = meta_&dataset;
    by name;
  run;

  /* Get the unique variables-formats pairs from the central metadata and add it to the cohort's metadata */;
  proc sort data = meta.metadata 
                   (where=(format^ in (" " "DATE" "DATETIME" "TIME"  "COMMA"  
                                       "HHMM"  "MMDDYY" "DDMMYY" "BEST" "$" 
                                       "DOLLAR" "$F")
                           )
                   ) 
             out = metaformat
             nodupkey;
    by libname name formatdot;
  run;

  proc sort data = metaformat;
    by name formatdot;
  run;

  data metaformat;
    set metaformat;
    by name formatdot;
    if first.name then count=0;
    count + 1;
    if last.name;
    if count=1;
    keep libname memname name format formatdot count;
  run;

  proc freq data = metaformat;
    table libname / list;
  run;

  data metadata;
    merge meta_&dataset (in = in_orig)
          metaformat    (in = in_metadata 
                         keep = name format formatdot 
                         rename =(format=format_metadata formatdot=formatdot_metadata)
                        );
    by name;
    if in_orig;
    if format in ('' '$') then do;
      format    = format_metadata;
      formatdot = formatdot_metadata;
    end;
  run;

  **************************;
  ***       VIMO         ***;
  **************************; 

  %vimo(
    ds      		= &cohort,
    path    		= &path,
    metalib 		= work,
    time    		= &time,
    id      		= &dqliteid,
	scriptsWINpath	= &scriptsWINpath
  )

  **************************;
  ***       TIM          ***;
  **************************;
  %if &_datevar^= AND &startyyyy^= AND &endyyyy^= %then %do;
    %tim(
      library = &library,
      data    = &dataset,
      start   = &startyyyy,
      end     = &endyyyy,
/*      time    = &time,*/
      refdate = &_datevar,
      path    = &path
    )

  %end;

  **************************;
  ***    LINKABILITY     ***;
  **************************;
  %if &_datevar^= AND &linktype^= AND &linktypefmt^= AND &startyyyy^= AND &endyyyy^= %then %do;

  %linkability(
    ds          = &cohort,
    bydate      = &_datevar,
    linktype    = &linktype,
    linktypefmt = &linktypefmt,
    startyr     = &startyyyy,
    endyr       = &endyyyy,
    time        = &time,
    path        = &path
  )

  %end;

  **************************;
  ***       TREND        ***;
  **************************;
  %if &_datevar^= AND &startyyyy^= AND &endyyyy^= %then %do;

  %trend(
    ds       = &cohort,
    startyr  = &startyyyy,
    endyr    = &endyyyy,
    bydate   = &_datevar,
    %IF &byvar^= %THEN %DO;
      byvar     = &byvar,
    %END;
    time     = &time,
    path     = &path
  )

  %end;

  **************************;
  ***  Data Dictionary   ***;
  **************************;
  %if &dictionary = ON %then %do;
    %dictionary(
      libname      = &library,
      dataset      = &dataset,
      metadata     = metadata,
      fmtlib      = formats,
      path         = &path,
      lookupsubdir = Lookup,
      varsubdir    = Variables,
      shownvalue   = 20,
      title        = The Data Dictionary for &library..&dataset
    )
  %end;

  **************************;
  ***  Delete temp data  ***;
  **************************;
  proc datasets lib=work;
    delete meta_&dataset metadata metaformat ;
  quit;

%mend;


