/*========================================================================  
DataFit Toolkit - Program for Initiating simulated data 
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
Program				: createSimulatedData
Purpose				: Macro call to generate simulated data 
Programmer			: Gangamma Kalappa
Date				: 24-July-2015
Output library		: WORK
Output dataset		: hospitalization,referencedata.
*******************************************************************************************************************************
*******************************************************************************************************************************/
%createSimulatedData (nobs  = 505062,
					  endyr = 2014,
					  noyrs = 10
					  );
