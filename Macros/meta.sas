/*========================================================================  
DataFit Toolkit - Meta macro
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


/*_____________________________________________________________________________________
  | MACRO:       META  
  |
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Mahmoud Azimaee
  |
  | DATE:        June 2011
  |
  | DESCRIPTION: This Macro generates a Metadata dataset using
  |              PROC CONTENTS with OUT option for a single or a series of
  |              datasets within a specified LIB to be used in
  |              Data Quality and Documentation Processes.
  |              The output data will be saved in &OUTLIB directory. All
  |              output Metadata datasets must be appended to a central
  |              Metadata.
  |              The output dataset will be named as Meta_[DS]
  |
  | PARAMETERS:  LIB= SAS library name that you want to create metadata for
  |
  |              DS= dataset prefix or complete name of dataset in &LIB. If left blank
  |                  metadata will be created for the entire LIBNAME.
  |
  |              EXCL = Dataset name to exclude from metadata
  |
  |              FMTLIB= SAS library name(s) containing the format cataloges
  |                      (default is Formats)
  |
  |              PATH= Location for a text file containing variable names
  |                    along with their associated formats (Tab/Space delimitted)
  |
  |              OUTLIB= SAS library name for output dataset
  |                      (default is Meta)
  |              LOG = OFF/ON
  |                    Turn off the log whiel running %META macro
  |                    (default is OFF)
  |
  | EXAMPLE:     %META (LIB=ohip,
  |                     DS =ohip ,
  |                     FMTLIB=meta2,
  |                     PATH='/prod/HDL/metadata/varlists/ohip_varlist.txt');
  |
  | EXAMPLE:     %META (LIB=HOBIC,
  |                     EXCL = formats_cntlout,
  |                     FMTLIB=meta2,
  |                     PATH='/prod/HDL/metadata/varlists/hobic_varlist.txt');
  |
  | EXAMPLE:     %META (LIB=ohip,
  |                     DS =ohip,
  |                     outlib=tmp,
  |                     PATH='/deid/dq/metadata/varlists/ohip_varlist.txt');
  |
  | EXAMPLE:     %META (LIB=orgd,
  |                     DS =orgd,
  |                     outlib=tmp,
  |                     PATH='/deid/dq/metadata/varlists/orgd_varlist.txt');
  |
  | UPDATE:       April 2013 by Xiaoping Zhao
  |               - check if format in VARLIST file exist in format catalog
  |               - add idxusage sorted sortedby to metadata
  |               - add "lib" and "DS" parameter check
  |
  |               June 2013 by Xiaoping Zhao
  |               - fix the hidden characters in varlist data before matching
  |                 to the find the formats not in the catalog
  |
  |               July 2013 by Xiaoping Zhao
  |               - length memname in work._list_ file to be $50 to avoid
  |                 memname truncated.
  |
  |
  |               May 2014 by Mahmoud Azimaee
  |               - cd command was removed and modified wrteing and reading of _lst_.txt
  |
  |               June 2014 by Sean Ji
  |               - increase the length of formatdot from 32 to 33
  |
  |               Jan 2015 by Mahmoud Azimaee
  |               - Fundemental changes applied to the macro to make it compatible
  |					with SAS EG
  |
  |               March 2015 by Sean Ji
  |               - add option validvarname=v7; 
  |	
  |               April 2015 by Mahmoud Azimaee
  |               - add engine nobs compress ; 
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |
  |              Feb 2017, Gangamma Kalappa
  |              - Addded LOG=ON/OFF option; to turn OFF or ON the log while ruuning the macro  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
%MACRO META (DS=,
             LIB=,
             EXCL=,
             FMTLIB=FORMATS,
             PATH=,
             OUTLIB=META,
			 LOG=OFF);

	/*Feb 2017 update-Addition of parameter to turn off log by re-directing log to dummy file*/
  	%if %upcase(&LOG)=OFF %then %do;
      	filename junk dummy;
      	proc printto log=junk;
      	run;
  	%end;
  	/*End of Feb 2017 update-Addition of parameter to turn off log*/

    %local validvarname;
    %let validvarname=%sysfunc(getoption(validvarname, keyword));
    options validvarname=v7;

    %LET DS = %UPCASE(&DS);
    %LET LIB = %UPCASE(&LIB);
    %LET EXCL = %UPCASE(&EXCL);
    %LET PATH= %SYSFUNC(CAT("&PATH"));

    proc sql noprint;
      select distinct libname into :libexist
       FROM DICTIONARY.members
         WHERE LIBNAME = "&LIB";
    quit;

   %IF &DS ^= %THEN %DO;
    proc sql noprint;
      select distinct memname into :dataexist separated by " "
       FROM DICTIONARY.members
         WHERE LIBNAME = "&LIB" AND MEMTYPE="DATA"
                AND SUBSTR(MEMNAME,1,%SYSFUNC(LENGTH(&DS)))="&DS";
     quit;
   %END;

    %if %symexist(libexist)=0 %then %do;
      data _null_;
       %put ======================================================;
       %put | libname &LIB does not exist;
       %put ======================================================;
       abort;
      run;
    %end;

    %if &DS ^= & %symexist(dataexist)=0 %then %do;
      data _null_;
       %put ======================================================;
       %put | &DS is not found in library &LIB ;
       %put ======================================================;
       abort;
      run;
    %end;

    options FMTSEARCH = (&FMTLIB);

    PROC SQL NOPRINT;
         SELECT MEMNAME INTO :DSS SEPARATED BY " "
         FROM DICTIONARY.members
         WHERE LIBNAME = "&LIB" AND MEMTYPE="DATA"
            %IF &DS^= %THEN %DO;
                AND SUBSTR(MEMNAME,1,%SYSFUNC(LENGTH(&DS)))="&DS"
            %END;
            %IF &EXCL ^= %THEN %DO;
                AND MEMNAME ^= "&EXCL"
            %END;
            ;
     QUIT;

     %LET DSN=%EVAL(%SYSFUNC(COUNTC(&DSS,' '))+1);

     %DO I=1 %TO &DSN;
	 	 ods output EngineHost=EngineHost;
         PROC CONTENTS DATA=&LIB..%SCAN(&DSS,&I," ") OUT=contents&I
              (keep= libname memname memlabel name type length label format formatl formatd
                     idxusage sorted sortedby engine nobs compress crdate modate
               rename=(type=type1));
         run;

		data &LIB.&I;
			set &LIB..%SCAN(&DSS,&I," ") (obs=0);
			format %include &PATH; ;
		run;

		proc contents data=&LIB.&I noprint out=formats&I (keep=name format formatl formatd);
		run;

	   proc sql;
	         create table meta&I as
	         select 
					A.libname, A.memname, A.memlabel, A.name, A.type1, A.length, A.label, 
					A.idxusage, A.sorted, A.sortedby, A.engine, A.nobs, A.compress, A.crdate, A.modate,
					B.format, B.formatl, B.formatd
	         from Contents&I as A, formats&I as B
	         where A.name = B.name 
	         order by libname, memname;
	   quit;

		data work.enginehost;
			set work.enginehost;
			if label1 in ("Access Permission" "Owner Name" "File Size (bytes)" "Filename");
			keep Label1 cValue1;
		run;

		proc transpose data=work.enginehost out=perms&I (drop=_NAME_ rename=(COL1=path COL2=perm COL3=owner COL4=size));
			var  cValue1;
		run;

		%let memname=%SCAN(&DSS,&I," ");

		data perms&I;
			set perms&I;
			libname= symget('LIB') ;
			memname= symget ('memname');
			filename_length= length(scan(path,count(path,"/"),"/"));
			path=substr(path,1,length(path)-filename_length);
			drop filename_length;
		run;
		
         data Meta_&DS;
            %IF &I=1 %THEN %DO;
               set Meta&I;
            %END;
            %ELSE %DO;
              set Meta_&DS Meta&I;
            %END;
         run;

		 data perms;
            %IF &I=1 %THEN %DO;
               set perms&I;
            %END;
            %ELSE %DO;
              set perms perms&I;
            %END;
         run;

     %END;

     data Meta_&DS;
       set Meta_&DS ;
       length type $ 4 formatdot $ 33 ;
       if type1=1 then do;
         type='Num';
         if formatl ^= 0 then do;
            if formatd=0 then CALL CATS (formatdot, format, put(formatl,$12.),'.');
            else CALL CATS (formatdot, format, put(formatl,$12.),'.',put(formatd,$12.));
         end;
         else if format ^= '' then CALL CATS (formatdot, format, '.');
       end;
       else do;
           type='Char';
           if format ^in ('','$') then CALL CATS (formatdot, format, '.');
           if format = '$' then CALL CATS (formatdot, format, put(formatl,$12.), '.');
       end;
       name=upcase(name);
       drop type1 formatl ;
    run;

   proc sql;
         %IF &DS^= %THEN %DO;
             create table &OUTLIB..Meta_&DS as
         %END;
         %ELSE %DO;
             create table &OUTLIB..Meta_&LIB as
         %END;
         select A.*, B.* /* B.perm, B.owner, B.size, B.path */
         from Meta_&DS as A, PERMS as B
         where A.memname = B.memname & A.libname = B.libname
         order by libname, memname;
   quit;

*** keep original variables order and put indexby sorted sortedby to the last;
   data %IF &DS^= %THEN %DO; &OUTLIB..Meta_&DS (Compress=CHAR) %END;
        %ELSE %DO; &OUTLIB..Meta_&LIB  (Compress=CHAR) %END;;

     retain libname memname memlabel name length label
            formatd format type formatdot path perm owner
            idxusage sorted sortedby size engine nobs compress crdate modate;

     set
        %IF &DS^= %THEN %DO; &OUTLIB..Meta_&DS %END;
        %ELSE %DO; &OUTLIB..Meta_&LIB %END;;
	 label perm = 'File Access Permission'
	 	   owner = 'File Owner Name'
		   size = 'File Size (bytes)'
		   path = 'File Physical Location'
		   formatdot = 'Variable Format (Including the $ and .) '
		   Type = 'Variable Type';
   run;

**** Delete Temporary datasets and files;
     PROC DATASETS;
       delete contents1-contents&I
			  formats1-formats&I
              Meta1-Meta&I
           	  PERMS1-PERMS&I
			  &LIB.1-&LIB.&I
			  PERMS
			  _meta_
              meta_
              ENGINEHOST
              %IF %UPCASE(&OUTLIB) ^= WORK %THEN %DO;
                  Meta_&DS
              %END;
			  ;
       run;
     quit;

   /****************************************************************
     restore the option: validvarname 
   *****************************************************************/
   options &validvarname;

   /*Feb 2017 update-Addition of parameter to turn off log-reset to default EG session setting by re-directing log from dummy to log window*/
   %if %upcase(&log)=OFF %then %do;
    	proc printto log=log;
    	run;
    %end;
  /*End of Feb 2017  update-Addition of parameter to turn off log*/

%MEND META;
