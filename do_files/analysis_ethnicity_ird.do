**** ANALYSIS DO-FILE FOR CONDUCTING ANALYSIS OF TREATMENT EFFECT HETEROGENITY BY ETHNICITY ANALYSIS ON ADDITIVE SCALE ****

* Define program
capture program drop prog_ethnicity_ird
program define prog_ethnicity_ird

syntax, outcome(string) [filter(string)]

* outcome		// file name of outcome of interest
* eventdate 	// variable name for event date of outcome
* filter		// optional string with filtering of analysis population for renal 

qui {
	* Load outcomes and find earliest outcome per patient
	use  "${datadir}\outcomes\`outcome'.dta", clear
	drop if eventdate==.
	sort  ptid eventdate

	preserve 
		use ptid rxst wt treatment exposed SCr eth4 using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_SA.dta", clear
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_WHITE.dta", keep(ptid rxst wt treatment exposed SCr eth4)
		append using "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_BLACK.dta", keep(ptid rxst wt treatment exposed SCr eth4)
		
		* dataset includes transferred out of practice date (tod), death date and practice last collection date (lcd) 
		merge m:1 ptid using "${datadir}\censor_vars.dta", keep(master match) nogen

		tempfile forMerge
		save `forMerge', replace
	restore 
	merge 1:m ptid rxst  using `forMerge', keep(using match) nogen

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

	*********************************************************************************
		* MODELLING *
	*********************************************************************************
	* recode exposed as 1 for ARB, 0 for ACEi to aid will model comparison
	drop exposed 
	gen exposed=1 if treatment=="ARB"
	replace exposed=0 if treatment=="ACEi"

	* OVERALL
	* Poisson model to estimate incidence rate ratios
	poisson status i.exposed  [pw=wt], exposure(_t) vce(robust) irr  nolog

	* Margins command to generate incidence rates 
	margins i.exposed, predict(ir) post

	* Overall incidence rate difference for ARB vs ACEi as percentages per 5.5 years
	nlcom (rd: (_b[1.exposed]*550) - (_b[0.exposed]*550)), post
	
	* HETEROGENITY
	* Incidence rate difference for ARB vs ACEi for Black ethnic group as percentages per 5.5 years
	poisson status i.exposed##i.eth4  [pw=wt], exposure(_t) vce(robust) irr  nolog
 
	margins i.exposed#i.eth4, predict(ir) post
	
	nlcom (rd: (_b[1.exposed#2.eth4]*550) - (_b[0.exposed#2.eth4]*550)), post
	
	* Incidence rate difference for ARB vs ACEi for South Asian ethnic group as percentages per 5.5 years
	poisson status i.exposed##i.eth4  [pw=wt], exposure(_t) vce(robust) irr  nolog

	margins i.exposed#i.eth4, predict(ir) post

	nlcom (rd: (_b[1.exposed#1.eth4]*550) - (_b[0.exposed#1.eth4]*550)), post

	* Incidence rate difference for ARB vs ACEi White ethnic group as percentages per 5.5 years
	poisson status i.exposed##i.eth4  [pw=wt], exposure(_t) vce(robust) irr  nolog

	margins i.exposed#i.eth4, predict(ir) post

	nlcom (rd: (_b[1.exposed#0.eth4]*550) - (_b[0.exposed#0.eth4]*550)), post

	* Statistical test of heterogenity using incidence rate differences
	poisson status i.exposed##i.eth4  [pw=wt], exposure(_t) vce(robust) irr  nolog

	margins i.exposed#i.eth4, predict(ir) post

	test  ((_b[1.exposed#2.eth4]*550) - (_b[0.exposed#2.eth4]*550))=((_b[1.exposed#1.eth4]*550) - (_b[0.exposed#1.eth4]*550))=((_b[1.exposed#0.eth4]*550) - (_b[0.exposed#0.eth4]*550))
	
}

end


* 1. Primary composite outcome 
prog_ethnicity_ird, outcome(primary)

* 2. Main secondary outcome 
prog_ethnicity_ird, outcome(main_secondary) 

* 3. MI 
prog_ethnicity_ird, outcome(MI) 

* 4. Stroke 
prog_ethnicity_ird, outcome(stroke) 

* 5. Hospitalisation for HF 
prog_ethnicity_ird, outcome(hosp_HF) 

* 6. CV death 
prog_ethnicity_ird, outcome(CV_dth) 

* 7. non-CV death 
prog_ethnicity_ird, outcome(non_CV_dth) 

* 8. All-cause mortality 
prog_ethnicity_ird, outcome(all_dth) 

* 9. Loss of GFR or ESKD
prog_ethnicity_ird, outcome(nephropathy1) filter(SCr)

* 10. ESKD
prog_ethnicity_ird, outcome(nephropathy2) filter(SCr)

* 11. Doubling of creatinine 
prog_ethnicity_ird, outcome(SCr_dbl) filter(SCr)

* 12. Angioedema 
prog_ethnicity_ird, outcome(angioedema) 

