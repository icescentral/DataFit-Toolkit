/*========================================================================  
DataFit Toolkit - MakePage macro
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
  | MACRO:       makepages
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Kinwah Fung
  |
  | DATE:       
  |
  | DESCRIPTION: Create HTML pages for each variable
  |              This macro is the sub-macro of %Dictionary
  |
  | PARAMETERS:  
  |             VARLIST      = Input dataset, which listed all the
  |                            variables in the dataset, for which 
  |                            we create the the data dictionary. 
  |
  |             CODELIST     = Input dataset, for the variables
  |                            you want to show the list of values.
  |
  |             DETAILLIST   = 
  |
  |             NOTESLIST    = Input dataset, for the variables
  |                            you want to show the notes.  
  |
  |             LINKLIST     = 
  |
  |             PATH         = The full path for the folder holding
  |                            the &subdirectory, which is holding 
  |                            all the pages for the variables.
  |
  |             SUBDIRECTORY = The name of the folder under &path, 
  |                            which holds all the pages for the 
  |                            variables.
  |
  |             TITLE        = The title for the HTML pages.
  |
  |
  | EXAMPLE: 
  |             %makepages(
  |               varlist      = variables2,
  |               codelist     = fmt,
  |               detaillist   = ,
  |               noteslist    = ,
  |               linklist     = ,
  |               path         = /users/sji/temp,
  |               subdirectory = Variables,
  |               title        = The Data Dictionary
  |             )  
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
/*****************************************************************************
   Create HTML pages
*****************************************************************************/
%macro makepages(
  varlist      = , 
  codelist     = , 
  detaillist   = , 
  noteslist    = ,   
  linklist     = ,
  path         = ,
  subdirectory = ,
  title        =
);

%IF &sysscp^=WIN %THEN %DO; 
  systask command "mkdir -p /&path/&subdirectory" wait;
%END;

/*****************************************************************************
   Create individual pages for each variable 
   Create a list of MACRO variables   
*****************************************************************************/
  proc sql noprint;
    select distinct lowcase(name) into: listvariables separated by " "
    from &varlist;
  
    select count(distinct name) into: numvar
    from &varlist;

    select distinct path into: location
    from &varlist
    where monotonic() =1;

    select distinct libname into: libname
    from &varlist
    where monotonic() =1;

    select distinct memname into: memname
    from &varlist
    where monotonic() =1;

  quit;
  
/*  %put LOCATION inside the Macro =&location ;*/

  %macro callvar;
    %do i = 1 %to &numvar;
      *** (1) get the variable ***;
      %let var&i = %trim(%scan(&listvariables,&i));
  
      *** (2) get data element LABEL, TYPELEN, Format, Formatdot, Description and File Owner ***;

      proc sql noprint; 
        select trim(label) into: label
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)";
  
        select trim(typelen) into: typelen
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)";
  
    select trim(format) into: format
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)";

        select trim(formatdot) into: formatdot
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)";
  
        select compress(showvalue) into: showvalue
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)";

    select lookuplink into: lookuplink
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)" & lowcase(showvalue)='f';

    select available into: available
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)";

%IF &sysscp^=WIN %THEN %DO;
    select owner into: owner
        from &varlist
        where lowcase(NAME) = "%lowcase(&&var&i)";
%END;
      quit;
  

/*****************************************************************************
   Label Type/Length formatdot
*****************************************************************************/
      data dummy1;
        length info $50 fulltext $2000;
      
          /* Label */
          info = 'Label:';
          fulltext = "&label";
          output;
      
          /* Type/Length */
          info = 'Type/Length:';
          fulltext = "&typelen";
          output;

          /* Availability */
          info = 'Available in:';
          fulltext = "&available";
          output;

	%IF &sysscp^=WIN %THEN %DO;
          /* File Onwer */
          info = 'File Owner:';
          fulltext = "&owner";
          output;
	%END;
          /* Format */
          info = 'Format:';
          %if %length(&format) > 0 %then %do;
            fulltext = "&formatdot";
          %end;
          %else %do;
            fulltext = ' ';
          %end;
      output;

      run;

/*****************************************************************************
   All values with descriptions depending whether you want to show the list
   of values.
   Sometimes you don't want to list here, instead you ask the user to click
   a link
*****************************************************************************/
      %if %lowcase(&showvalue) = f %then %do;
        data dummy2;
          set &codelist (where = (lowcase(format) = "%lowcase(&format)")) end = last;
          length info $50 fulltext $2000;
          retain info fulltext;
          if _n_ = 1 then do;
            info = 'Values:'; ;
            fulltext = "&lookuplink";
          end;
          if _n_ = 1 then output;
        run;
       %end;

       %if %lowcase(&showvalue) = t %then %do;
        data dummy2;
          set &codelist (where = (lowcase(format) = "%lowcase(&format)")) end = last;
          length info $50 fulltext $2000;
          retain info fulltext;
          if _n_ = 1 then do;
            info = 'Values:'; ;
            fulltext = strip(start)||' = '||strip(label)||" ~n";
          end;
          else do;
            fulltext = strip(fulltext) ||
                       strip(start)||' = '||strip(label)||" ~n";
          end;
        
          if last then output;
        run;
       %end;

       %else %if %length(&showvalue) = 0 %then %do;
        data dummy2;
          length info $50 fulltext $2000;
          info = 'Values:'; ;
          fulltext = " ";
          output;
        run;
       %end;


/*****************************************************************************
   All notes
*****************************************************************************/
      %if %length(&noteslist) > 0 %then %do;
        data dummy3;
          set &noteslist (where = (lowcase(name) = "%lowcase(&&var&i)")) end = last;
          length info $50 fulltext $2000;
          retain info fulltext;
          if _n_ = 1 then do;
            info = 'Notes:'; ;
            if notes^='' then fulltext = input('2022'x, $UCS2B4.)|| " " ||strip(notes)||" ~n";
          end;
          else if notes^='' then do;
            fulltext = strip(fulltext) ||input('2022'x, $UCS2B4.)|| " " ||strip(notes)||" ~n";
          end;  
          if last then output;
        run;
      %end;

/*****************************************************************************
   All links
*****************************************************************************/
      %if %length(&noteslist) > 0 %then %do;
        data dummy4;
          set &noteslist (where = (lowcase(name) = "%lowcase(&&var&i)")) end = last;
          length info $50 fulltext $2000;
          retain info fulltext;
          if _n_ = 1 then do;
            info = 'Links:'; ;
            if link^='' then fulltext = strip(link)||" ~n";
          end;
          else if link^='' then do;
            fulltext = strip(fulltext) ||strip(link)||" ~n";
          end;
          if last then output;
        run;
      %end;

      data dummy;
        set dummy1 
            dummy2 
            %if %length(&noteslist) > 0 %then %do;
              dummy3
              dummy4
            %end; 
        ;
        if compress(info) in ('Notes:', 'Links:', '') & compress(fulltext)in ('~n') then delete;
        keep info fulltext;
      run;

    ods PATH work.templat(update) sasuser.templat(read) sashelp.tmplmst(read);
      proc template;
        define style defaultback;
          parent = styles.default;
          replace color_list /
            'bgA'  = cxFFFFFF
            'bgA1' = cxFFFFFF
            'bgA2' = cxFFFFFF
            'bgA3' = cxFFFFFF
            'bgA4' = cxFFFFFF
            'bgH' = cxFFFFFF
            'bgT' = cxFFFFFF
            'bgD' = cxFFFFFF
            'bg' = cxFFFFFF
            'fg' = cxFFFFFF;
        end;

        define table varpage;
          mvar titleone;
          dynamic categoryheader;
          column (col1) (col2);
          header table_header_1;
            define table_header_1;
              text "Variable %upcase(&&var&i)";
              style = {background = white color = cx00669D Font_size=4};
            end;
      
            define col1;
              generic=on;
              header = categoryheader;
              style = {just = left background = white Font_size=3};
            end;
      
            define col2;
              generic=on;
              header = categoryheader;
              style = {just = left background = white Font_size=3};
            end;
        end;
      run;

      ods _ALL_ close;
      ods escapechar = '~';
      ods html file = "&path/&subdirectory/&&var&i...html" (title = "Variable - &&var&i");
      footnote bcolor = white color = cx00669D height = 2 justify = r "This page was last updated on %sysfunc(date(), worddate.)";
      
      %let titleone = ALL;
      
      title;
      data _null_;
        set dummy;
      
        file print 
          ods = (template='varpage'
                 columns=
                   (col1=info(generic=on)
                    col2=fulltext(generic=on)));
        put _ods_;
      run;

      ods html close;

    %end;

 %put LOCATION outside the Macro =&location;

/*****************************************************************************
   Data Dictionary Page (list of variables)
   - create hyperlink if the variable has look-up table
*****************************************************************************/
  title height = 4 color = cx00669D bcolor = white "&title" ;
  footnote bcolor = white color = cx00669D height = 2 justify = r "This page was last updated on %sysfunc(date(), worddate.)";
  %IF &dataset ^= %THEN 
              %let text=Data Dictionary ~n ~n
                        Dataset Name: &dataset ~n
                        /*Location on UNIX: &location ~n*/
                        Library Name: &libname;
  %ELSE 
              %let text=Data Dictionary ~n ~n
                        Dataset Name: All the datasets within the Library ~n
                        /*Location on UNIX: &location ~n*/
                        Library Name: &libname;

  ods PATH work.templat(update) sasuser.templat(read) sashelp.tmplmst(read);
  proc template;
    define style DefaultBack;
      parent = styles.default;
      replace color_list /
        'bgA'  = cxFFFFFF
        'bgA1' = cxFFFFFF
        'bgA2' = cxFFFFFF
        'bgA3' = cxFFFFFF
        'bgA4' = cxFFFFFF
        'bgH' = cxFFFFFF
        'bgT' = cxFFFFFF
        'bgD' = cxFFFFFF
        'bg' = cxFFFFFF
        'fg' = cxFFFFFF;
      end;

    define table recordlayout;
      mvar titleone;
      dynamic categoryheader;
      column (col1) (col2) (col3) (col4) (col5);
      header table_header_1;
        define table_header_1;
          text "&text";
          style = {background = white font_face = 'Arial' Font_size=4};
        end;
  
        define col1;
          generic=on;
          header = 'Variable Name';
          style = {background = white font_face = 'Arial' Font_size=3};
        end;

        define col2;
          generic=on;
          header = 'Label';
          style = {background = white font_face = 'Arial' Font_size=3};
        end;
 
        define col3;
          generic=on;
          header = 'Type/Length';
          style = {background = white font_face = 'Arial' Font_size=3};
        end;

        define col4;
          generic=on;
          header = 'Format';
          style = {background = white font_face = 'Arial' Font_size=3};
        end;

	%IF &sysscp^=WIN %THEN %DO;
        define col5;
          generic=on;
          header = 'File Owner';
          style = {background = white font_face = 'Arial' Font_size=3};
        end;
	%END;
    end;
  run;  

  ods _ALL_ close;

  %if &dataset ^= %then %do;
    %let file=&path/%sysfunc(strip(&libname))_%sysfunc(strip(&dataset))_dictionary.html;
  %end;
  %else %do; 
    %let file=&path/%sysfunc(strip(&libname))_datadic.html;
  %end;

  ods escapechar = '~';
  ods html file = "&file" (title = "Data Dictionary for &dataset");
  footnote bcolor = white color = cx00669D height = 2 justify = r "This page was last updated on %sysfunc(date(), worddate.)";

  %let titleone = ALL;

  title;
  data _null_;
  set &varlist;
  file print 
    ods = (template='recordlayout'
           columns=(col1=varlink(generic=on)
             col2=label(generic=on)
                  col3=typelen(generic=on)
            col4=formatdot(generic=on)
			%IF &sysscp^=WIN %THEN %DO;
	            col5=owner(generic=on)
    		%END;        
          ));
  put _ods_;
  run;

  ods html close;

  %mend callvar;

  %callvar;

  ods listing;

%mend makepages;
