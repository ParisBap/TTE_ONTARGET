**** ANALYSIS DO-FILE FOR SENSITIVITY ANALYSIS: ANALYSIS AFTER MULTIPLE IMPUTATION OF MISSING BP AND CREATININE AT BASELINE ****

* Define program
capture program drop prog_MI_analysis
program define prog_MI_analysis

syntax, outcome(string) [filter(string)]

* outcome		// file name of outcome of interest
* filter		// optional string with filtering of analysis population for renal 

qui {
	
	* Load outcomes and find earliest outcome per patient
	use  "${datadir}\outcomes\`outcome'.dta", clear
	drop if eventdate==.
	sort ptid eventdate

	preserve 
		use ptid rxst wt treatment exposed eth4 SCr_i _mj _mi using  "${datadir}/sensitivity/MI/mi_white_all", clear
		append using "${datadir}/sensitivity/MI/mi_sa_all", keep(ptid rxst wt treatment exposed eth4 SCr_i _mj _mi)
		append using "${datadir}/sensitivity/MI/mi_blk_all", keep(ptid rxst wt treatment exposed eth4 SCr_i _mj _mi)
			
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
	
	* set data using inverse-probability weights
	stset eventdt [pw=wt], failure(status) origin(rxst)  scale(365.25) 

	*********************************************************************************
	* MODELLING *
	*********************************************************************************
	encode treatment, gen(treatment_int) //change to numeric

	** Overall effect estimate ARB vs ACEi **
	mim: stcox i.treatment_int
	
	** Treatment effect estimate in White ethnic group ARB vs ACEi **
	mim: stcox i.treatment_int##i.eth4
	
	** Treatment effect estimate in South Asian ethnic group ARB vs ACEi **
	mim: lincom 2.treatment_int + 2.treatment_int#1.eth4, eform // SA
	
	** Treatment effect estimate in Black ethnic group ARB vs ACEi **
	mim: lincom 2.treatment_int + 2.treatment_int#2.eth4, eform // black
	
}

end

* 1. Primary composite outcome 
prog_MI_analysis, outcome(primary)

* 2. Main secondary outcome 
prog_MI_analysis, outcome(main_secondary) 

* 3. MI 
prog_MI_analysis, outcome(MI) 

* 4. Stroke 
prog_MI_analysis, outcome(stroke) 

* 5. Hospitalisation for HF 
prog_MI_analysis, outcome(hosp_HF) 

* 6. CV death 
prog_MI_analysis, outcome(CV_dth) 

* 7. non-CV death 
prog_MI_analysis, outcome(non_CV_dth) 

* 8. All-cause mortality 
prog_MI_analysis, outcome(all_dth) 

* 9. Loss of GFR or ESKD
prog_MI_analysis, outcome(nephropathy1) filter(SCr)

* 10. ESKD
prog_MI_analysis, outcome(nephropathy2) filter(SCr)

* 11. Doubling of creatinine 
prog_MI_analysis, outcome(SCr_dbl) filter(SCr)

* 12. Angioedema 
prog_MI_analysis, outcome(angioedema) 



