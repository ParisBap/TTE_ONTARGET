**** ANALYSIS DO-FILE FOR CONDUCTING ANALYSIS OF TREATMENT EFFECT HETEROGENITY BY ETHNICITY ANALYSIS ON MULTIPLICATIVE SCALE ****

* Define program
capture program drop prog_ethnicity
program define prog_ethnicity

syntax, outcome(string) [filter(string)]

* outcome		// file name of outcome of interest
* filter		// optional string with filtering of analysis population for renal 

qui {
	* Load outcomes and find earliest outcome per patient
	use  "${datadir}\outcomes\`outcome'.dta", clear
	drop if eventdate==.
	sort ptid eventdate

	preserve 
		use ptid rxst wt treatment exposed SCr eth4 using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_SA.dta", clear
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_WHITE.dta", keep(ptid rxst wt treatment exposed SCr eth4)
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_BLACK.dta", keep(ptid rxst wt treatment exposed SCr eth4)

		merge m:1 ptid using "${datadir}\censor_vars.dta", keep(master match) nogen
		tempfile forMerge
		save `forMerge', replace
	restore 
	merge 1:m ptid rxst using `forMerge', keep(using match) nogen

	if "`filter'"!="" {
		keep if `filter'!=.
	}
		
	* create variable of maximum FU (5.5 years since start of eligible period)
	gen FUdate=rxst+(365.25*5.5) 

	* create variable earliest of: outcome or censor date (at earliest of: tod, deathdate, lcd or 5.5yrs of FU if other censor dates don't occur)
	gen eventdt=min(eventdate, tod, deathdate, lcd, FUdate) 
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

	* get number of events by ethnic group
	bysort eth4: tab treatment status, row

	*********************************************************************************
	* MODELLING *
	*********************************************************************************
	encode treatment, gen(treatment_int) //change to numeric

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
prog_ethnicity, outcome(primary)

* 2. Main secondary outcome 
prog_ethnicity, outcome(main_secondary) 

* 3. MI 
prog_ethnicity, outcome(MI) 

* 4. Stroke 
prog_ethnicity, outcome(stroke) 

* 5. Hospitalisation for HF 
prog_ethnicity, outcome(hosp_HF) 

* 6. CV death 
prog_ethnicity, outcome(CV_dth) 

* 7. non-CV death 
prog_ethnicity, outcome(non_CV_dth) 

* 8. All-cause mortality 
prog_ethnicity, outcome(all_dth) 

* 9. Loss of GFR or ESKD
prog_ethnicity, outcome(nephropathy1) filter(SCr)

* 10. ESKD
prog_ethnicity, outcome(nephropathy2) filter(SCr)

* 11. Doubling of creatinine 
prog_ethnicity, outcome(SCr_dbl) filter(SCr)

* 12. Angioedema 
prog_ethnicity, outcome(angioedema) 

