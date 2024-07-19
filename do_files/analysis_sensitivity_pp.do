**** ANALYSIS DO-FILE FOR SENSITIVITY PER-PROTOCOL ANALYSIS: DISCONTINUE (END OF ELIGIBLE PERIOD), SWITCH OR START DUAL THERAPY WILL BE INCLUDED UP TO AND INCLUDING DATE OF LAST STUDY DRUG + 60 DAYS ****

capture program drop prog_getPP_dts
program define prog_getPP_dts

syntax, treatment(string) switchdrug(string) 

* treatment		// name of treatment of interest (ACEi or ARB)
* switchdrug	// name of opposing drug that patient may switch to (opposite med to treatent)

qui {		
	
	** 1. Get date of last study drug **
	* use prescription data with derived end dates
	use ptid rxst rxen using "${datadir}/prescriptions/prescriptions_`treatment'.dta", clear

	* keep only for patients included in main analysis

	preserve 
		use ptid rxst treatment using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_SA.dta", clear
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_WHITE.dta", keep(ptid rxst treatment)
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_BLACK.dta", keep(ptid rxst treatment)
		
		keep if treatment=="`treatment'"
		* rename rxst to date so unique when merging onto prescriptions
		rename rxst date 
		duplicates drop 
		
		tempfile forMerge
		save `forMerge', replace
	restore 

	merge m:1 ptid using `forMerge', keep(match) nogen 

	* drop prescriptions before start of eligible period 
	drop if rxst<date

	* get date of last prescription for study drug of interest
	sort ptid date rxst 

	* generate variable of start date of last prescription study drug by each eligible period
	by ptid: gen last_med=rxst if _n==_N

	* generate variable of end date of last prescription for each eligible period
	by ptid: gen last_med_en=rxen if _n==_N
	format last_med last_med_en %td

	** 2. Get date of treatment switch (i.e, prescription for comparator drug and no subsequent prescriptions for assigned drug) **
	preserve 
		* keep 1 obs per period
		keep if last_med!=. 
		keep ptid last_med date
		
		* merge on prescriptions for other study drug (drug switching)
		merge 1:m ptid using "${datadir}/prescriptions/prescriptions_`switchdrug'.dta", keep(match) keepusing(ptid rxst rxen) nogen 
		sort ptid date rxst rxen 
		
		* drop prescriptions before start of eligible period 
		drop if rxst<date
		
		* keep if prescriptions are after last study drug of interest date 
		keep if rxst>=last_med
		keep ptid rxst 
		sort ptid rxst 
		
		* select earliest date receives prescription for comparator drug
		by ptid: keep if _n==1
		rename rxst switch_dt 
		tempfile forMerge 
		save `forMerge', replace 
	restore 

	merge m:1 ptid using `forMerge', keep(master match) nogen 

	keep if last_med!=.
	keep ptid date switch_dt last_med_en

	duplicates drop 
	 
	save "${datadir}/sensitivity/PP/prescriptions_PP_`treatment'.dta", replace

	** 3. Date of becoming dual user **
	* conduct on patients included in analysis 

	use ptid rxst treatment using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_SA.dta", clear
	append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_WHITE.dta", keep(ptid rxst treatment)
	append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_BLACK.dta", keep(ptid rxst treatment)
		
	keep if treatment=="`treatment'"
	* rename rxst to date so unique when merging onto dual therapy exposed periods
	rename rxst date 
	duplicates drop 

	* get dual therapy exposed periods
	preserve 
		use ptid rxst using "${datadir}/exposed periods/exposed_periods_dual.dta", clear 
		gen treatment="dual"
		sort ptid rxst 
		by ptid: gen id=_n 
		* transition to wide format as small number of exposed periods
		reshape wide rxst , i(ptid) j(id)
		tempfile forMerge 
		save `forMerge', replace 
	restore 

	merge m:1 ptid using `forMerge', keep(master match) nogen 

	gen dual=0 
	gen dual_dt=.

	* loop through each unique start of dual therapy exposed period
	forvalues n=1/14 {
		* flag as become dual user if start of dual exposed period is between start and end of single therapy exposed period 
		replace dual=1 if rxst`n'>=date & rxst`n'<rxen_new & rxst`n'!=.
		* set dual user start date as date of exposed period that meets criteria above
		replace dual_dt=rxst`n' if dual==1 & rxst`n'!=.
	} 
	format dual_dt %td
	drop rxst*
		
	* merge onto prescriptions with PP dates created above 
	merge 1:1 ptid date using "${datadir}/sensitivity/PP/prescriptions_PP_`treatment'.dta", nodup 

	** 4. Get date of last study drug + 60 days: earliest of discontinuation, switch or becomes dual therapy user **
	sort ptid date 
	gen gen last_drug_dt=min(switch_dt, dual_dt, last_med_en)
	format last_drug_dt %td

	** get censor date: last_drug_dt+60 days
	gen PP_dt=last_drug_dt+60
	format PP_dt %td 

	keep PP_dt last_drug_dt date ptid
	gen treatment="`treatment'"

	* change date variable back to rxst
	rename date rxst 

	* save as PP dates for analysis 
	save "${datadir}/sensitivity/PP/`treatment'_PP_dates.dta", replace

}
end 

** ACEi PATIENTS **
define prog_getPP_dts, treatment("ACEi") switchdrug("ARB") 

** ARB PATIENTS **
define prog_getPP_dts, treatment("ARB") switchdrug("ACEi") 

**************** PP ANALYSIS *****************

* Define program
capture program drop prog_PP_analysis
program define prog_PP_analysis

syntax, outcome(string) [filter(string)]

* outcome		// file name of outcome of interest
* filter		// optional string with filtering of analysis population for renal 

qui {
	* load in analysis population datasets 
	use ptid rxst wt treatment exposed SCr using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_SA.dta", clear
	append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_WHITE.dta", keep(ptid rxst wt treatment exposed SCr)
	append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_BLACK.dta", keep(ptid rxst wt treatment exposed SCr)
	
	* merge on data with PP dates 
	preserve 
		use "$datadir/sensitivity/PP/ACEi_PP_dates.dta", clear 
		append using "${datadir}/sensitivity/PP/ARB_PP_dates.dta"
		
		tempfile forMerge
		save `forMerge', replace
	restore 
	
	merge 1:1 ptid rxst treatment using `forMerge', keep(master match) nogen 
	
	* merge on censor variables 
	merge m:1 ptid using "${datadir}\censor_vars.dta", keep(master match) nogen
	
	* merge on outcomes 
	preserve 
		* Load outcomes and find earliest outcome per patient
		use  "${datadir}\outcomes\`outcome'.dta", clear
		drop if eventdate==.
		sort ptid eventdate
		
		tempfile forMerge
		save `forMerge', replace
	restore 
	
	merge m:1 ptid rxst using `forMerge', keep(master match) nogen
	
	* apply filter for study population if required (renal outcomes)
	if "`filter'"!="" {
		keep if `filter'!=.
	}
		
	* create variable of maximum FU (5.5 years since start of eligible period)
	gen FUdate=rxst+(365.25*5.5) 

	* create variable earliest of: outcome or censor date (at earliest of: tod, deathdate, lcd, additional PP follow up date (switch, last date of study drug or becomes dual user) or 5.5yrs of FU if other censor dates don't occur)
	gen eventdt=min(eventdate, tod, deathdate, lcd, PP_dt FUdate) // additionally includes last study drug date + 60 days (PP_dt)
	format eventdt %td

	* create variable flagging if patient has the outcome of interest (status=1) or censored (status=0)
	gen status=1 if eventdate==eventdt
	replace status=0 if status==.

	* summarise all events
	tab status

	* set data using inverse-probability weights
	stset eventdt [pw=wt], failure(status) origin(rxst)  scale(365.25) 

	* summarise
	summ _t, detail

	* get number of events
	tab treatment status, row

	*********************************************************************************
	* MODELLING *
	*********************************************************************************
	
	encode treatment, gen(treatment_int) //change to numeric

	** Overall effect estimate **
	* Cox model for ARB vs ACEi 
	stcox treatment_int, vce(robust)

	* Check proportional hazards assumption using plot of scaled Schoenfeld residuals 
	estat phtest, plot(treatment_int)
	
	** Heterogeneity by ethnicity **
	* Cox model for ARB vs ACEi with interaction between treatment and ethnicity
	stcox i.treatment_int##i.eth4, vce(robust)

	* Statistical test for heterogenity by ethnicity using a Wald test 
	test 2.treatment_int#0.eth4 2.treatment_int#1.eth4 2.treatment_int#2.eth4
	
	* treatment estimates for South Asian ethnic group
	lincom 2.treatment_int + 2.treatment_int#1.eth4, eform 

	* treatment estimates for Black ethnic group
	lincom 2.treatment_int + 2.treatment_int#2.eth4, eform
	
	* Check proportional hazards assumption using plot of scaled Schoenfeld residuals within strata of ethnicity
	
	* White ethnic group
	stcox treatment_int if eth4==0, vce(robust)
	estat phtest, plot(treatment_int)
	
	* South Asian ethnic group
	stcox treatment_int if eth4==1, vce(robust)
	estat phtest, plot(treatment_int)
	
	* Black ethnic group
	stcox treatment_int if eth4==2, vce(robust)
	estat phtest, plot(treatment_int)
	
}

end

* 1. Primary composite outcome 
prog_PP_analysis, outcome(primary)

* 2. Main secondary outcome 
prog_PP_analysis, outcome(main_secondary) 

* 3. MI 
prog_PP_analysis, outcome(MI) 

* 4. Stroke 
prog_PP_analysis, outcome(stroke) 

* 5. Hospitalisation for HF 
prog_PP_analysis, outcome(hosp_HF) 

* 6. CV death 
prog_PP_analysis, outcome(CV_dth) 

* 7. non-CV death 
prog_PP_analysis, outcome(non_CV_dth) 

* 8. All-cause mortality 
prog_PP_analysis, outcome(all_dth) 

* 9. Loss of GFR or ESKD
prog_PP_analysis, outcome(nephropathy1) filter(SCr)

* 10. ESKD
prog_PP_analysis, outcome(nephropathy2) filter(SCr)

* 11. Doubling of creatinine 
prog_PP_analysis, outcome(SCr_dbl) filter(SCr)

* 12. Angioedema 
prog_PP_analysis, outcome(angioedema) 



