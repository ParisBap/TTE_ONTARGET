**** ANALYSIS DO-FILE FOR BENCHMARKING ANALYSIS ****

* Define program
capture program drop prog_benchmarking
program define prog_benchmarking

syntax, outcome(string) [filter(string)]

* outcome		// file name of outcome of interest
* filter		// optional string with filtering of analysis population for renal 

qui {
	* Load outcomes and find earliest outcome per patient
	use  "${datadir}\outcomes\`outcome'.dta", clear
	drop if eventdate==.
	sort ptid eventdate

	preserve 
		use ptid rxst wt treatment exposed SCr using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_SA.dta", clear
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_WHITE.dta", keep(ptid rxst wt treatment exposed SCr)
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_BLACK.dta", keep(ptid rxst wt treatment exposed SCr)

		* dataset includes transferred out of practice date (tod), death date and practice last collection date (lcd) 
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

	* get number of events
	tab treatment status, row

	*********************************************************************************
	* MODELLING *
	*********************************************************************************
	encode treatment, gen(treatment_int) //change to numeric

	* Cox model for ARB vs ACEi 
	stcox treatment_int, vce(robust)

	* Check proportional hazards assumption using plot of scaled Schoenfeld residuals 
	estat phtest, plot(treatment_int)
}

end

* 1. Primary composite outcome 
prog_benchmarking, outcome(primary)

* 2. Main secondary outcome 
prog_benchmarking, outcome(main_secondary) 

* 3. MI 
prog_benchmarking, outcome(MI) 

* 4. Stroke 
prog_benchmarking, outcome(stroke) 

* 5. Hospitalisation for HF 
prog_benchmarking, outcome(hosp_HF) 

* 6. CV death 
prog_benchmarking, outcome(CV_dth) 

* 7. non-CV death 
prog_benchmarking, outcome(non_CV_dth) 

* 8. All-cause mortality 
prog_benchmarking, outcome(all_dth) 

* 9. Doubling of creatinine 
prog_benchmarking, outcome(SCr_dbl) filter(SCr)

