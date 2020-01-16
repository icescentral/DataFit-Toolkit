/*========================================================================  
DataFit Toolkit - TIMFreq macro
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
 |  MACRO:       TIMEFREQ
 |
 |  JOB:         Data Quality
 |
 |  PROGRAMMER:  Gangamma Kalappa
 |
 |  DATE:       17 Oct 2014
 |
 |  DESCRIPTION: This macro is a part of VIMO macros. This Macro creates a
 |               SAS datasets called timefreq.sas7bdat in the work directory.
 |               It contains frequnecies for each time variables with
 |               formats, which defined by hour in %VIMO. It also
 |               contains number of missing values. This data set will be
 |               used later in %freq_html.
 | UPDATE:
 |
 |              Nov 2016, Mahmoud Azimaee
 |              - Major updates on all macros in order to make them compatible with SAS PC  
 |            
  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯*/


%MACRO TIMEFREQ;
       proc format lib=work;
            value tbyhr 1  ="1:00 - 1:59"
                        2 ="2:00 - 2:59"
                        3 ="3:00 - 3:59"
                        4 ="4:00 - 4:59"
                        5 ="5:00 - 5:59"
                        6 ="6:00 - 6:59"
                        7 ="7:00 - 7:59"
                        8 ="8:00 - 8:59"
                        9 ="9:00 - 9:59"
                        10 ="10:00 - 10:59"
                        11 ="11:00 - 11:59"
                        12 ="12:00 - 12:59"
                        13 ="13:00 - 13:59"
                        14 ="14:00 - 14:59"
                        15 ="15:00 - 15:59"
                        16 ="16:00 - 16:59"
                        17 ="17:00 - 17:59"
                        18 ="18:00 - 18:59"
                        19 ="19:00 - 19:59"
                        20 ="20:00 - 20:59"
                        21 ="21:00 - 21:59"
                        22 ="22:00 - 22:59"
                        23 ="23:00 - 23:59"
                        0 = "00:00 - 00:59"
                        ;

           value valtime    23<-high = 'Invalid'
                            low-<0   = 'Invalid'
                            other    = 'Valid'
                        ;
       run;

       %local dsid obscnt rc i timeby fmt;

       %let timeby =%upcase(hour);
       %let valhrstart =0;
       %let valhrend =23;

       data timefmt;
            set &METALIB..metadata;
            where libname = "&lib" & memname="&dsn" & lowcase(type)='num' &
                  format in ('TIME')  & upcase(name) not in (&idin);
            keep name format;
       run;

       %if %sysfunc(exist(timefmt)) %then %do;
            %let dsid=%sysfunc(open(timefmt));
            %let obscnt=%sysfunc(attrn(&dsid,nlobs));
            %let rc=%sysfunc(close(&dsid));
       %end;

       %if &timeby=HOUR %then %do;
              %let fmt=tbyhr.;
       %end;

       %if &obscnt > 0 %then %do;
           %if %sysfunc(exist(timefreq)) %then %do;
              proc datasets lib=work memtype=data;
                delete timefreq;
              quit;
              run;
            %end;

           data timefreq;
                length value $   50
                count      8
                varname $ 32;
                stop;
           run;

            proc sql noprint;
                 select strip(name),
                         format
                         into  :varlist separated " ",
                               :fmtlist separated " "
                  from   timefmt;
            quit;

            %let doi=%eval(%sysfunc(countc(&varlist,' '))+1);
            %do i=1 %to &doi;
                  %let timevar = %scan(&varlist, &i, ' ');
                  %let timefmt = %scan(&fmtlist, &i, ' ');

                  %let valfmt=valtime.;
                  %let applyfmt=put(hour(&timevar), &fmt.);

                  proc sql noprint;
                       create table timevarfreq as
                              select case put(hour(&timevar), &valfmt.)
                                     when 'Invalid' then '(Invalid)'
                                     when 'Valid' then &applyfmt.
                                     end as  value length=50,
                                     count(&timevar) as count length=8,
                                     nmiss(&timevar) as misscnt length=8,
                                     upcase("&timevar") as varname length=32
                                     from   &lib..&dsn(keep=&timevar)
                                     group by value
                                 ;
                  quit;

                  data timevarfreq;
                       set timevarfreq;
                       if strip(value)='.' then do;
                           Count=misscnt;
                           value='(Missing Value)';
                       end;
                       drop misscnt;
                  run;


                  proc sort data=timevarfreq sortseq=linguistic(numeric_collation=ON);
                       by value;
                  run;

                  proc datasets nolist;
                       append base=timefreq data=timevarfreq;
                       delete timearfreq;
                  quit;
             %end;

             data charfreq;
                   set charfreq
                       timefreq;
             run;
         %end;

 %MEND TIMEFREQ;
