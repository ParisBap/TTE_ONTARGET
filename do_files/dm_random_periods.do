**** DATA MANAGEMENT DO FILE TO SELECT ONE RANDOM TRIAL-ELIGIBLE PERIOD PER PATIENT TO USE IN ANALYSIS ****

** select random period **
use ptid rxst using "${datadir}\Trial_eligible_periods_ACEi.dta", clear
gen exposed=1
gen treatment="ACEi"

append using "${datadir}\Trial_eligible_periods_ARB.dta", keep(ptid rxst)
replace treatment="ARB" if treatment==""
replace exposed=0 if exposed==. 

* check for data errors study period 01jan01-31jul19
drop if year(rxst)>2019

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

sort exposed ptid rxst

* select random sample 1 period per patient
sample 1, count by(exposed ptid)

save "${datadir}\1 PERIOD PER PT - RANDOM\random_period.dta", replace



