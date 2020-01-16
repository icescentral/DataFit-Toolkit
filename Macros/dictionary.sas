/*========================================================================  
DataFit Toolkit - Dictionary macro
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
  | MACRO:       dictionary
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Kinwah Fung
  |
  | DATE:       
  |
  | DESCRIPTION: Create the Data Dictionary for a data set, which
  |              including a  data dictionary html page and two 
  |              subfolders holding all the lookup pages.
  |              This macro is a submacro of %dqlite.
  |
  |
  | PARAMETERS:  
  |              LIBNAME      = The library name for the input dataset.
  |
  |              DATASET      = The name of the input dataset.
  |
  |              METADATA     = The dataset holding the metadata info 
  |                             for &dataset.
  |                             The default value is: meta.metadata.
  |
  |              FMTLIB      =  Format library. (Default value is FORMATS)
  |
  |              PATH         = The full path for the folder holding
  |                             the &lookupsubdir and &varsubdir, 
  |                             which are holding all the pages for
  |                             the formats and the variables, 
  |                             respectively.
  |
  |              LOOKUPSUBDIR = The name of the folder under &path, 
  |                             which holds all the pages for the 
  |                             format values. Default value: Lookup.
  |
  |              VARSUBDIR    = The name of the folder under &path, 
  |                             which holds all the pages for the 
  |                             variables. Default value: Variables.
  |
  |              SHOWNVALUE   = The threshold, if the formated values
  |                             less than or euqal to this number. All
  |                             the values will be showed in variable
  |                             page in &varsubdir, otherwise all the
  |                             values will be shown in a separated 
  |                             page in &lookupsubdir. Default value
  |                             is 20.
  |
  |              TITLE        = The title for the HTML pages.
  |
  |
  | EXAMPLE: 
  |              %dictionary(
  |                libname      = work,
  |                dataset      = mycohort,
  |                metadata     = metadata,
  |                fmtlib      = formats,
  |                path         = /users/sji/temp,
  |                lookupsubdir = Lookup,
  |                varsubdir    = Variables,
  |                shownvalue   = 20,
  |                title        = The Data Dictionary for &libname..&dataset    
  |              );
  |
  | UPDATES: 
  |              May 2016, Sean Ji
  |                - Add the header for this macro
  |                - Let the macro create the &subdirectory 
  |                  automatically
  |              
  |       
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
    ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
%macro dictionary(
  libname      = ,
  dataset      = ,
  metadata     = meta.metadata,
  fmtlib      = formats,
  path         =,
  lookupsubdir = Lookup,
  varsubdir    = Variables,
  shownvalue   = 20,
  title        =
);

 proc format lib = &fmtlib
	cntlout = dqliteformats(keep = fmtname start end label hlo);
 run;
  *** First check if there are common variables among the LIBNAME with different formats assigned;
  proc sort data=&metadata (where=(libname=upcase("&libname")) keep=libname memname name format) out=variables;
    by name format;
  run;
  data variables;
    set variables;
    by name format;
    if first.name & ^first.format;
  run;
   
  %GETNOBS(variables);
   
  %IF &NO^=0 %THEN %DO;
    %put Warning: There are Variables in these selected datasets with same names but different formats. Check the following variables. Macro will STOP. ;
    proc print data=variables;
      var memname name;
    run;
    %GOTO ENDMACRO;
  %END;

  *** Select the required information from Metadata;
  data variables;
    set &metadata;
    %IF &dataset ^= %THEN %DO;
      if upcase(libname)=upcase("&libname") & upcase(memname)=upcase("&dataset");
    %END;
    %ELSE if libname="&libname";;
    name = upcase(name);
    length typelen $20;
    typelen = compress(type)||compress(length);
    if substr(format,1,1)='$' then format=substrn(format,2,length(format)-1);
    if format='' then formatdot='';
  run;
  
  *** Add Availability of variables in the different datasets within the libname ***;
  proc sort data=variables (keep=memname name) out=availability;
    by name;
  run;

  data availability;
    length available $ 2000;
    set availability;
    retain available;
    by name;
    if first.name then available='';
    if ^last.name then available = compress(available)||memname||', ';
    if last.name then available = compress(available)||memname;
    if last.name;
    available=TRANWRD(available, ",",",  ");
    drop memname;
  run;

  proc sort data=variables;
    by name;
  run;
  
  data variables;
    merge variables availability;
    by name;
  run;

  %IF &dataset = %THEN %DO;
    proc sort data=variables nodupkey;
      by name label;
    run;
    ** Pick the variable that has Label;
    data variables;
      set variables;
      by name label;
      if last.name & last.label;
    run;
  %END;
  %ELSE %DO;
    proc sort data=variables nodupkey;
      by name memname format;
    run;
  %END;
  
  proc sort data=variables (keep=name format) out=fmt_unique nodupkey;
    by format;
  run;

  proc sql;
    create table fmt as
    select a.fmtname as format, a.start, a.end, a.label, a.HLO
    from dqliteformats as a , fmt_unique as b
    where a.fmtname=b.format;
  quit;

  *** Check if the formats are on-to-one formats or interval formats;
  
  data fmt;
    set fmt;
    if start ^=end then start = strip(start) || ' - ' || strip(end);
    if HLO = 'F' then label= 'Original value formated as ' || label;
    drop HLO;
  run;

   *** Remove duplicates from FMT dataset;
   *** If there are numeric and charachter formats with the same name like 
     $YESNO. and YESNO. then they appear twice. ;

   proc sort data=fmt nodupkey;
       by format label;
   run;

  /*****************************************************************************
     determine whether or not to show the list of variables
     Decision: not to show if the number of distinct values is > 15
     Links:
     > if # of formatted values > 15, then create a link to the lookup table
     instead showing the list of values in the intranet page

  *****************************************************************************/
  proc sql;
    create table fmtcount as
    select format, count(distinct start) as valuecnt
    from fmt
    group by format;
  quit;

  proc sort data=variables;
    by format;
  run;

  data variables;
    merge variables fmtcount;
    by format;
    varlink = "~S={url='./&varsubdir/"||
                strip(lowcase(scan(name,1)))||
           ".html'}"||
                    name;
    if valuecnt=. then showvalue='';
      else if valuecnt <= &shownvalue then showvalue = 'T';
          else if valuecnt > &shownvalue then showvalue = 'F';
    length lookuplink $200;
    if showvalue='F' then do;
      linknum = 0;
      lookuplink = "~S={url='../&lookupsubdir/"||
          strip(lowcase(scan(format,1)))||
          ".html'}Click here for values and descriptions.";
    end;
  run;

  /*****************************************************************************
     Create HTML pages for the lookup tables
  *****************************************************************************/
  proc sql;
    create table lookuptables as
    select fmt.format, fmt.start, fmt.label 
    from fmt, fmtcount
    where fmt.format=fmtcount.format & fmtcount.valuecnt > &shownvalue;
  quit;

  %makelookup(
    fmtlist = lookuptables,
    path=&path,
    subdirectory = &lookupsubdir
  );

  /*****************************************************************************
     Sort the data by name so that dx10code2 is always before dx10code10
  *****************************************************************************/
  data variables (drop = stop init);
    set variables;
    length namepart2 8; 
    if substr(compress(name),length(compress(name)),1) in 
      ('0' '1' '2' '3' '4' '5' '6' '7' '8' '9') then do;
      stop = 0;
      init = length(compress(name));
      do while (stop = 0);
         if substr(compress(name),init,1) not in ('0' '1' '2' '3' '4' '5' '6' '7' '8' '9') 
          then stop = init;
          init = init - 1;
      end;
      namepart1 = substr(compress(name), 1, stop);
      namepart2 = compress(substr(compress(name), stop+1, length(compress(name)) - stop));
    end;
    else do;
      namepart1 = compress(name);
      namepart2 = .;
    end;
  run;

  proc sql;
    create table variables2 (drop = namepart1 namepart2) as
    select *
    from variables
    order by namepart1, namepart2;
  quit;


  /*****************************************************************************
     Create Data Dictionary and Variable pages
  *****************************************************************************/
  %makepages(
    varlist      = variables2,
    codelist     = fmt,
    detaillist   = ,
    noteslist    = /*notes*/,
    linklist     = ,
    path         = &path,
    subdirectory = &varsubdir,
    title        = &title
  );

  proc datasets lib=work;
    delete Dummy: fmt fmtcount lookuptables notes variables variables2 availability dqliteformats;
    quit;
  run;

  %ENDMACRO:

%mend dictionary;
