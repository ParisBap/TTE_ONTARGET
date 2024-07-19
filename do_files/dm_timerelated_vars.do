**** DATA MANAGEMENT DO-FILE USED TO CREATE TIME-RELATED VARIABLES TO BE USED IN PROPENSITY SCORE MODEL TO ACCOUNT FOR TREATMENT SWITCHERS AND PREVALENT USERS ****

* generate time since 1st eligible period variable (either exposure)
* append ARB and ACEi trial eligible periods
use rxst ptid using "${datadir}\Trial_eligible_periods_ACEi.dta", clear
gen treatment="ACEi"
	
append using "${datadir}\Trial_eligible_periods_ARB.dta", keep(ptid rxst)
replace treatment="ARB" if treatment==""

* drop periods where both treatments received on the same day
sort ptid rxst 
by ptid rxst: gen trt=treatment if _n==1
by ptid rxst: replace trt=trt[_n-1] if trt==""
gen dup=1 if treatment!=trt
preserve	
	keep if dup==1
	keep ptid rxst 
	tempfile forMerge
	save `forMerge', replace
restore 
merge m:1 ptid rxst using `forMerge', keep(master) nogen
drop dup trt

* calculate time since first exposure of monotherapy
sort ptid rxst 
by ptid: gen firstperiod=rxst if _n==1
format firstperiod %td
by ptid: replace firstperiod=firstperiod[_n-1] if firstperiod==.
gen timesince=rxst-firstperiod 
label var timesince "Time since first eligible period of either drug"

save "${datadir}\timerelated_vars.dta", replace

* generate no. of previous ACEi periods 
use ptid rxst using "${datadir}\Trial_eligible_periods_ACEi.dta", clear
gen treatment="ACEi"
	
append using "${datadir}\Trial_eligible_periods_ARB.dta", keep(ptid rxst)
replace treatment="ARB" if treatment==""

gen trt=1 if treatment=="ACEi"
sort ptid rxst
by ptid: gen trt1=trt[_n-1] 
sort ptid rxst 
bysort ptid: gen aceicounter=cond(missing(trt1), . , sum(!missing(trt1)))
sort ptid rxst
by ptid: replace aceicounter=aceicounter[_n-1] if aceicounter==.
by ptid: replace aceicounter=0 if aceicounter==.
label var aceicounter "Number of prior acei periods"
drop trt trt1

* generate no. of previous acei periods
gen trt=1 if treatment=="ARB"
sort ptid rxst
by ptid: gen trt1=trt[_n-1] 
sort ptid rxst 
bysort ptid: gen arbcounter=cond(missing(trt1), . , sum(!missing(trt1)))
sort ptid rxst
by ptid: replace arbcounter=arbcounter[_n-1] if arbcounter==.
by ptid: replace arbcounter=0 if arbcounter==.
label var arbcounter "Number of prior arb periods"
drop trt trt1

merge 1:1 ptid rxst treatment using "${datadir}\timerelated_vars.dta", keep(match) nogen

save "${datadir}\timerelated_vars.dta", replace
