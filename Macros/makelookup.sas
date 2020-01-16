/*========================================================================  
DataFit Toolkit - MakeLookup macro
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
  | MACRO:       MAKELOOKUP
  | JOB:         Data Quality
  |
  | PROGRAMMER:  Kinwah Fung
  |
  | DATE:       
  |
  | DESCRIPTION: Create HTML pages for lookup tables
  |              This macro is the sub-macro of %Dictionary
  |
  | PARAMETERS:  
  |              FMTLIST       = Input dataset, which listed all the 
  |                              formats the used in the dataset, 
  |                              for which we creat the the data 
  |                              dictionary. Default: Lookuptables
  |                         
  |              PATH          = The full path for the folder holding
  |                              the &subdirectory, which is holding 
  |                              all the lookup tables.
  |
  |              SUBDIRECTORY  = The name of the folder under &path, 
  |                              which holds all the lookup tables.
  |                              Default: Lookup
  |
  |
  | EXAMPLE: 
  |             %makelookup( path = /users/sji/temp );    
  |
  | UPDATES: 
  |              May 2016, Sean Ji
  |                - Let the macro create the &subdirectory 
                     automatically
  |
  |              Nov 2016, Mahmoud Azimaee
  |              - Major updates on all macros in order to make them compatible with SAS PC  
  |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
/*****************************************************************************
   Create HTML pages for lookup tables
*****************************************************************************/
%macro makelookup(
  fmtlist      = lookuptables, 
  path         = ,
  subdirectory = Lookup
);

%IF &sysscp^=WIN %THEN %DO; 
  systask command "mkdir -p /&path/&subdirectory" wait;
%END;
  /*****************************************************************************
   Create individual pages for each variable 
   Create a list of MACRO variables   
  *****************************************************************************/
  proc sql noprint;
    select distinct lowcase(format) into: listvariables separated by " "
    from &fmtlist;
  
    select count(distinct format) into: numvar
    from &fmtlist;
  quit;
  
  %macro callvar;
    %do i = 1 %to &numvar;
      *** get the variable ***;
      %let var&i = %trim(%scan(&listvariables,&i));

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
              text "Lookup Table for $%upcase(&&var&i).";
              style = {background = white color = cx00669D  Font_size=4};
            end;
      
            define col1;
              generic=on;
              header = categoryheader;
              style = {just = left background = white  Font_size=3};
            end;
      
            define col2;
              generic=on;
              header = categoryheader;
              style = {just = left background = white  Font_size=3};
            end;
        end;
      run;

      ods _ALL_ close;
      ods escapechar = '~';
      ods html file = "&path/&subdirectory/%lowcase(&&var&i).html" (title = "Lookup table - %upcase(&&var&i)");
      footnote bcolor = white color = cx00669D height = 2 justify = r "This page was last updated on %sysfunc(date(), worddate.)";
      
      %let titleone = ALL;
      
      title;
      data _null_;
        set &fmtlist (where = (lowcase(scan(format,1)) = "%lowcase(&&var&i)"));
      
        file print 
          ods = (template='varpage'
                 columns=
                   (col1=start(generic=on)
                    col2=label(generic=on)));
        put _ods_;
      run;
      ods html close;
    %end;
  %mend callvar;

  %callvar;

  ods listing;

%mend makelookup;
