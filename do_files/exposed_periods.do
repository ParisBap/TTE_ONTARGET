**** DO-FILE TO GENERATE PRESCRIPTION END DATES AND EXPOSED PERIODS ****

capture program drop exposedperiods
program define exposedperiods

syntax, treatment(string) partn(integer) loopn(integer)

* treatment		// name of treatment (ACEi or ARB)

qui {		      						
	/*******************************************************************************
	* calculate prescription end date for all drugs of interest 
	i. duration
	ii. impute a median duration to missing and extreme values (duration<7 or duration>90)
	********************************************************************************/
	di in red "obs `i'"
	
	use "${rawdata}/CPRD/DrugIssue/drug_issue_extract", clear

	* keep for medication of interest 
	merge m:1 prodcodeid using "${codelistdir}/`treatment'_prodcodes.dta", keep(match) nogen 
	
	* add on dosage information from look up files
	merge m:1 dosageid using "${datadir}\Lookup files\common_dosages.dta", keep(master match) nogen

	drop dosageid
	count
	replace quantity=. if quantity<0
	
	* impute median to missing and extreme values
	preserve
		drop if duration==.
		keep if duration>=7 & duration<=90
		summ duration, detail
		return list
	restore
	replace duration=r(p50) if duration==. | duration<7 | duration>90

	di in yellow "Any missing value for rx_dur"
	count if duration==.

	* Generate prescription start date
	gen rxst = date(issuedate, "DMY")
	
	* if issue date missing use medication enter date if non-missing
	replace rxst=date(enterdate, "DMY") if issuedate==""
	format rxst %td
	
	* keep smallest integer of duration 
	gen duration2=ceil(duration)

	summ duration2, detail
	
	* generate prescription end date using start date + duration
	gen rxen=rxst+duration2-1
	format rxen %td

	* identify data erros
	count if rxen<rxst

	keep ptid prodcodeid rxst rxen  productname drugsubstancename 

	/***********************************************************************************
	Drop prescriptions that: 1. occur after death; 2. are after lcd tod
	*********************************************************************************/
	* merge on patient file to get required variables
	merge m:1 ptid using "${rawdata}/CPRD/Patient.dta", keepusing(pracid yob regstartdate acceptable regenddate) keep(master match) nogen

	* keep if patient is acceptable 
	keep if acceptable==1
	
	* transferred out date as registration end date and concert to numeric
	gen tod = date(regenddate, "DMY")
	format tod %td 
	
	* convert registration start date to numeric
	gen regstdt=date(regstartdate, "DMY")
	format regstdt %td 
	
	* drop if prescription occurs before registration start date
	drop if rxst<regstdt
	
	* drop if prescription occurs after transferred out date 
	drop if rxst>=tod

	* merge practice file to get last collection date
	merge m:1 pracid using "${rawdata}/CPRD/Practice.dta", keepusing(lcd) keep(match master) nogen

	* convert last collect date to numeric
	gen lcd2 = date(lcd, "DMY")
	format lcd2 %td 
	
	drop lcd 
	rename lcd2 lcd
	
	* drop if prescription occurs after last collection date
	drop if rxst>=lcd
	
	* merge on deaths from linked data to delete prescriptions that occur after death date (data error)
	merge m:1 ptid using "${rawdata}\Linked data\deaths.dta", keepusing(dod) keep(master match) nogen
	
	* convert death date to numeric drop if prescription occurs after death
	gen deathdate=date(dod, "DMY")
	format deathdate %td
	drop dod
	drop if rxst>=deathdate & deathdate!=.
	
	* save sensible prescriptions with generated end dates
	save "${datadir}/prescriptions/prescriptions_`treatment'.dta", replace
	
	/***********************************************************************************
	Determine eligible periods, i.e treatment gaps of nomore than 90 days after previous prescription
	*********************************************************************************/
	sort ptid rxst

	* create a flag to identify incorrect prescription dates
	gen flag1=.
	label variable flag1 "sensible eventdate"
	
	* only keep prescription dates that occur before the end of study period and occurred after year of birth (data error)  
	replace flag1=1 if rxst<td(31jul2019) & yob<year(rxst) 
	drop yob 
	drop if flag1==.
	drop flag1

	* identify no. of days between prescription end date and start of subsequent prescription per patient, if less than 90 days combine prescriptions to create exposed period of continuous therapy.
	sort ptid rxst
	gen firstrx=.
	
	* flag first prescription per patient
	by ptid: replace firstrx=1 if _n==1
	
	* calculate difference between prescription start date and end of previous prescription
	by ptid: gen nodays90=rxst-rxen[_n-1] 

	* generate flag which identifies if gap of >90 days occurs between prescriptions or first prescription per patient i.e., start of exposed period
	gen flag2=.
	label variable flag2 "exposed period"
	
	replace flag2=1 if (nodays90>=90 | firstrx==1)
	* for patients first prescription add number of days between the end of this prescription and subsequent as by default would be missing
	by ptid: replace nodays90=nodays90[_n+1] if firstrx==1 & nodays90==.

	* drop all prescription records before study start
	drop if rxst<td(1jan2001)
	
	* flags first and last prescriptions within exposed periods per patient
	sort ptid flag2 rxst
	gen firstlast=.
	label variable firstlast "first and last eligible period"
	by ptid flag2: replace firstlast=1 if _n==_N
	replace firstlast=1 if flag2==1
	sort ptid rxst
	by ptid: replace firstrx=1 if _n==1
	by ptid: replace firstlast=1 if _n==1

	* keep only first and last prescriptions within exposed periods per patient
	keep if firstlast==1

	* create variable with date of end of last prescription in exposed periods 
	gen rxen_new=.
	sort ptid rxst
	by ptid: replace rxen_new=rxen[_n+1] 
	format rxen_new %td

	* if patient only has one prescription thats in the exposed period use original prescription end date
	replace rxen_new=rxen if rxen_new==. & firstrx==1
	replace rxen_new=rxen if firstrx==1 & nodays90>90
	replace rxen_new=rxen if flag2==1 & rxen_new==.

	* keep prescription in start of exposed period 
	keep if flag2==1

	* drop flags and create new uniqueid
	drop firstrx nodays90 flag2 firstlast regstartdate regenddate

	sort ptid rxst 
	by ptid: gen uniqueid=_n 

	save "${datadir}/exposed periods/exposed_periods_`treatment'.dta", replace

}
end
exposedperiods, treatment("ACEi") 
exposedperiods, treatment("ARB")



