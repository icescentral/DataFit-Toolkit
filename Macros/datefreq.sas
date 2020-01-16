/*========================================================================  
DataFit Toolkit - DataFreq macro
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

/*___________________________________________________________________________
 |  MACRO:       DATEFREQ
 |
 |  JOB:         Data Quality
 |
 |  PROGRAMMER:  Sean Ji 
 |
 |  DATE:        April 2014
 |
 |  DESCRIPTION: This macro is a part of VIMO macros. This Macro creates a
 |               SAS datasets called datefreq.sas7bdat in the work directory.
 |               It contains frequnecies for each date variables with
 |               formats, which defined by parameter TIME in %VIMO. It also
 |               contains number of missing values. This data set will be
 |               used later in %freq_html.
 |
 |              Nov 2016, Mahmoud Azimaee
 |              - Major updates on all macros in order to make them compatible with SAS PC  
 |            
   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/
%macro datefreq;
  /**********************************************************************
    Initialization
  **********************************************************************/
  %local dsid obscnt rc i dateby  startyr endyr  fmt valfmt applyfmt ;
  %let dateby=%upcase(&time);
  %let startyr=1582;
  %let endyr=9999;
  
   
  /**********************************************************************
    get the date variables
  **********************************************************************/
  data datefmt;
    set &METALIB..metadata;
    where libname = "&lib" & memname="&dsn" & lowcase(type)='num' &
          format in ('DATE', 'DATETIME')  & upcase(name) not in (&idin);
    keep name format;
  run;

  /**********************************************************************
    check date variables exist or not
  **********************************************************************/
  %if %sysfunc(exist(datefmt)) %then %do;
    %let dsid=%sysfunc(open(datefmt));
    %let obscnt=%sysfunc(attrn(&dsid,nlobs));
    %let rc=%sysfunc(close(&dsid));
  %end;
  
  /**********************************************************************
    define the format according to the date range and the value of 
    &dateby macro variable
    NOTE: date range is between       "01JAN1582"(=-138061)
                        and           "31DEC9999"(=2936547)
                        
          datetime range is between   "01JAN1582:00:00:00'(=-11928470400)
                            and       "31DEC9999:59:59:59'(=253717747199)
  **********************************************************************/
  proc format;
    value valdate       2936547<-high = 'Invalid'
                        low-<-138061  = 'Invalid'
                        other         = 'Valid'
                        ;
                        
    value valdatetime   low-<-11928470400  = 'Invalid'
                        253717747199<-high = 'Invalid'
                        other              = 'Valid'
                        ;
  run;
  /**********************************************************************
    set format based on the parameter &time 
  **********************************************************************/
  %if &dateby=FISCAL %then %do;
      %fiscalyr(&startyr, %eval(&endyr-1)) ;;/* fiscal year end year is 9998 */
      %let fmt=fy.;
  %end;

  %if &dateby=CALENDAR %then %do;
      %calendaryr(&startyr,&endyr);;
      %let fmt=cy.;
  %end; 

  %if &dateby=QUARTERLY %then %do;
    %let fmt=yyq.;
  %end; 
  
  %if &dateby=MONTHLY %then %do;
      %let fmt=yymm8.;
  %end;
  
  
  %if &obscnt > 0 %then %do;
    /**********************************************************************
      create the datasets: datefreq and datetimefreq for appending
    **********************************************************************/
    %if %sysfunc(exist(datefreq)) %then %do;
      proc datasets lib=work memtype=data;
        delete datefreq;
      quit;
      run;
    %end;

    data datefreq;
      length value $   50
             count      8
             varname $ 32;
      stop;
    run;

    /**********************************************************************
      deal with the date and datetime varialbe 
    **********************************************************************/
    proc sql noprint;
      select strip(name), 
             format
             into  :varlist separated " ",
                   :fmtlist separated " "
      from   datefmt;
    quit;
    
    %do i=1 %to &sqlobs;
      %let datevar = %scan(&varlist, &i, ' ');
      %let datefmt = %scan(&fmtlist, &i, ' ');
      
      %if &datefmt=DATETIME %then %do;
        %let valfmt=valdatetime.;
        %let applyfmt=%quote(put(datepart(&datevar.), &fmt.));
      %end;  
      %else %do;
        %let valfmt=valdate.;
        %let applyfmt=%quote(put(&datevar, &fmt.)); 
      %end;
      
      /**********************************************************************
        get the the frequency count for date or datetime variable in
        each group. The group is defined by macro variable &dateby
      **********************************************************************/
	  %put 	fmt: &fmt. ;
	  %put 	valfmt: &valfmt. ;
	  %put  applyfmt: &applyfmt.;
      proc sql noprint;
        create table datevarfreq as
          select 
                 case put(&datevar, &valfmt.)
                   when 'Invalid' then '(Invalid)'
                   when 'Valid' then &applyfmt.
                 end as  value length=50,
                 count(&datevar) as count length=8,
                 nmiss(&datevar) as misscnt length=8,
                 upcase("&datevar") as varname length=32
          from   &lib..&dsn(keep=&datevar)
          group by value
          ;
      quit;
      run;
      
      data datevarfreq;
        set datevarfreq;
        if strip(value)='.' or strip(value)='Other Years' then do;
          Count=misscnt;
          value='(Missing Value)';
        end;
        drop misscnt;
      run;
      
      proc datasets nolist;
        append base=datefreq data=datevarfreq;
        delete datevarfreq;
      quit;
    %end;
    data charfreq;
      set charfreq
          datefreq;
    run;
  %end;
     
%mend datefreq;

