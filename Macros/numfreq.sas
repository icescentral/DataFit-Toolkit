/*========================================================================  
DataFit Toolkit - NumFreq macro
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
%macro NUMFREQ;

data numfmt;
     set &METALIB..metadata;

     where libname="&LIB" & memname="&DSN" & lowcase(type)='num' &
           format ^in ('','DATE','DATETIME','BEST','Z','TIME') &
           upcase(name) not in (&IDIN) ;
     keep NAME FORMATDOT;
run;


proc sql noprint;
    select nlobs into :obscnt from dictionary.tables
    where libname ='WORK' and memname='NUMFMT';
quit;


%if &obscnt %then %do;

  PROC SQL NOPRINT;
    SELECT strip(NAME) INTO :VARLIST SEPARATED " " FROM numfmt;
    SELECT FORMATDOT INTO :FMTLIST SEPARATED " " FROM numfmt;
  QUIT;

   %do nv=1 %to &sqlobs;
      %let numvar=%scan(&varlist, &nv, ' ');
      %let varfmt=%scan(&fmtlist, &nv, ' ');

      proc sql;
        create table numvar as
         select strip(put(&numvar, 32.)) as VALUE,
                strip(put(&numvar, &varfmt.)) as FORMATTEDVALUE length=200,
                count(&numvar) as Count,
                NMISS (&numVAR) AS MISSING,
                upcase("&numvar") as VARNAME length=32
                from &LIB..&DSN
                group by (&numVAR)
                order by VALUE;
      quit;

      data numvar;
        set numvar;
        if value=. then Count=missing;
      run;

      proc datasets nolist;
        append base=numfreq data=numvar;
        delete numvar;
      quit;
   %end;

  DATA CHARFREQ;
    SET CHARFREQ
        numfreq;

  RUN;

  PROC SORT DATA=CHARFREQ;
    BY VARNAME;
  RUN;

  %autolevel(data=numfreq, out=nfmtlevel);
  proc sort data=miss; by varname; run;
  proc sort data=nfmtlevel; by varname; run;

  data miss;
    merge miss(in=m)
          nfmtlevel(in=b);
    by varname;
    if m;

    if b then do;
       min=level;
    end;
    drop level;
  run;

  proc datasets nolist;
    delete numfreq numfmt;
  quit;
%end;
%mend NUMFREQ;
