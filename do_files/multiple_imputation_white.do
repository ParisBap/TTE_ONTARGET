**** DO-FILE TO IMPUTE MISSING VALUES FOR PATIENTS OF WHITE ETHNICITY USING MULTIPLE IMPUTATION OF CHAINED EQUATIONS ****

* set working directory
cd "${datadir}\sensitivity\MI\"

* import data
use "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_ps_model_vars_white.dta", clear

** drop if missing bmi, alcohol status or index of multiple deprivation. Only imputing for missing blood pressure and creatinine
drop if bmi==. | smokstatus==.  | imd_5==.

* keep variables used in PS model along with core variables and original creatinine (without imputed mean), don't include quadratric dbp until imputed 
keep stroke_TIA DM_prior PAD_any ageAtPeriod DM_comps CAD_any smokstatus bmicat sex statin nitrate DM_treatment diuretic ccb betablocker aspirin alphablocker antiplatelet oac imd_5  hospln year  sys_bp dia_bp timesince aceicounter arbln GP_apt SCr aceicounter2 timesince2 age2 ptid rxst exposed treatment     

* add on dataset containing primary outcome to improve quality of imputations
merge m:1 ptid using "${datadir}\censor_vars.dta", keep(master match) nogen

merge m:1 ptid rxst using "${datadir}\outcomes\primary.dta", keep(master match) nogen

* create variable earliest of: outcome or censor date (at earliest of: tod, deathdate, lcd or 5.5yrs of FU if other censor dates don't occur)
gen eventdt=min(eventdate, tod, deathdate, lcd, FUdate) 
format eventdt %td

* create variable flagging if patient has the outcome of interest (status=1) or censored (status=0)
gen status=1 if eventdate==eventdt
replace status=0 if status==.

* drop if event on start date as these would automatical be excluded if running stcox
drop if rxst==eventdate

* set data unweighted at this stage
stset eventdt, failure(status) origin(rxst)  scale(365.25)

* NA estimate of H(t) to be included with _d in imputation model
sts gen HT=na

search mvpatterns

* install packages required for MI
ssc install ice, replace 
ssc install mim, replace

* install package to transform non-normal continuous data to normality (once ran below click on nscore to install)
net from http://personalpages.manchester.ac.uk/staff/mark.lunt

* explore missingness will show which data is complete and which is nearly complete
mvpatterns stroke_TIA DM_prior PAD_any ageAtPeriod DM_comps CAD_any smokstatus bmicat sex statin nitrate DM_treatment diuretic ccb betablocker aspirin alphablocker antiplatelet oac imd_5  hospln year  sys_bp dia_bp timesince aceicounter arbln GP_apt aceicounter2 timesince2 age2 SCr    

* set up flags to identify obs in which particular vars are missing 
foreach var of varlist stroke_TIA DM_prior PAD_any ageAtPeriod DM_comps CAD_any smokstatus bmicat sex statin nitrate DM_treatment diuretic ccb betablocker aspirin alphablocker antiplatelet oac imd_5  hospln year  sys_bp dia_bp timesince aceicounter arbln GP_apt  aceicounter2 timesince2 age2 SCr _d HT  SCr {
	gen `var'_i = `var' 
}

* dry run to check format
ice stroke_TIA_i DM_prior_i PAD_any_i ageAtPeriod_i DM_comps_i CAD_any_i smokstatus_i bmicat_i sex_i statin_i nitrate_i DM_treatment_i diuretic_i ccb_i betablocker_i aspirin_i alphablocker_i antiplatelet_i oac_i imd_5_i hospln_i  year_i  sys_bp_i dia_bp_i timesince_i aceicounter_i arbln_i GP_apt_i aceicounter2_i timesince2_i age2_i SCr_i _d_i HT_i, dryrun

** first do 1 imputation to see form of continuous variables required: systolic BP, diastolic BP, creatinine. Impute separately within each exposed group. 
* unexposed
preserve 
	keep if exposed==0 
	nscore sys_bp_i SCr_i dia_bp_i , gen(nscore)
	
	ice nscore1-nscore3 stroke_TIA_i DM_prior_i PAD_any_i ageAtPeriod_i DM_comps_i CAD_any_i smokstatus_i bmicat_i sex_i statin_i nitrate_i DM_treatment_i diuretic_i ccb_i betablocker_i aspirin_i alphablocker_i antiplatelet_i oac_i imd_5_i hospln_i  year_i  timesince_i aceicounter_i arbln_i GP_apt_i aceicounter2_i timesince2_i age2_i _d_i HT_i , saving("miu_white", replace)  m(1)  seed(999)
	use miu_white, clear
	invnscore sys_bp_i SCr_i  dia_bp_i 
	save, replace
restore

* exposed 
preserve 
	keep if exposed==1 
	nscore sys_bp_i SCr_i dia_bp_i , gen(nscore)
		
	ice nscore1-nscore3 stroke_TIA_i DM_prior_i PAD_any_i ageAtPeriod_i DM_comps_i CAD_any_i smokstatus_i bmicat_i sex_i statin_i nitrate_i DM_treatment_i diuretic_i ccb_i betablocker_i aspirin_i alphablocker_i antiplatelet_i oac_i imd_5_i hospln_i  year_i  timesince_i aceicounter_i arbln_i GP_apt_i aceicounter2_i timesince2_i age2_i _d_i HT_i , saving("mit_white", replace)  m(1)  seed(999)
	use mit_white, clear
	invnscore sys_bp_i SCr_i  dia_bp_i 
	save, replace
restore

* use imputed data to check form of imputed continuous variables
use mit_blk, clear
append using miu_blk 
capture drop _merge 

* systolic BP
twoway hist sys_bp if exposed == 0, width(2) color(gs4) || hist sys_bp_i if sys_bp == . & exposed == 0, gap(50) color(gs12) width(2) legend(label(1 "Observed Values") label(2 "Imputed Values"))

twoway hist sys_bp if exposed == 1, width(2) color(gs4) || hist sys_bp_i if sys_bp == . & exposed == 1, gap(50) color(gs12) width(2) legend(label(1 "Observed Values") label(2 "Imputed Values"))

* diastolic BP
twoway hist dia_bp if exposed == 0, width(2) color(gs4) || hist dia_bp_i if sys_bp == . & exposed == 0, gap(50) color(gs12) width(2) legend(label(1 "Observed Values") label(2 "Imputed Values"))

twoway hist dia_bp if exposed == 1, width(2) color(gs4) || hist dia_bp_i if sys_bp == . & exposed == 1, gap(50) color(gs12) width(2) legend(label(1 "Observed Values") label(2 "Imputed Values"))

* BMI 
twoway hist bmi if exposed == 0, width(2) color(gs4) || hist bmi_i if sys_bp == . & exposed == 0, gap(50) color(gs12) width(2) legend(label(1 "Observed Values") label(2 "Imputed Values"))

twoway hist bmi if exposed == 1, width(2) color(gs4) || hist bmi_i if sys_bp == . & exposed == 1, gap(50) color(gs12) width(2) legend(label(1 "Observed Values") label(2 "Imputed Values"))

** now checked form, repeat imptution steps above with 10 imputations
* unexposed
preserve 
	keep if exposed==0 
	nscore sys_bp_i SCr_i dia_bp_i , gen(nscore)
	
	ice nscore1-nscore3 stroke_TIA_i DM_prior_i PAD_any_i ageAtPeriod_i DM_comps_i CAD_any_i smokstatus_i bmicat_i sex_i statin_i nitrate_i DM_treatment_i diuretic_i ccb_i betablocker_i aspirin_i alphablocker_i antiplatelet_i oac_i imd_5_i hospln_i  year_i  timesince_i aceicounter_i arbln_i GP_apt_i aceicounter2_i timesince2_i age2_i _d_i HT_i , saving("miu_white", replace)  m(10)  seed(999)
	use miu_white, clear
	invnscore sys_bp_i SCr_i  dia_bp_i 
	save, replace
restore

* exposed 
preserve 
	keep if exposed==1 
	nscore sys_bp_i SCr_i dia_bp_i , gen(nscore)
		
	ice nscore1-nscore3 stroke_TIA_i DM_prior_i PAD_any_i ageAtPeriod_i DM_comps_i CAD_any_i smokstatus_i bmicat_i sex_i statin_i nitrate_i DM_treatment_i diuretic_i ccb_i betablocker_i aspirin_i alphablocker_i antiplatelet_i oac_i imd_5_i hospln_i  year_i  timesince_i aceicounter_i arbln_i GP_apt_i aceicounter2_i timesince2_i age2_i _d_i HT_i , saving("mit_white", replace)  m(10)  seed(999)
	use mit_white, clear
	invnscore sys_bp_i SCr_i  dia_bp_i 
	save, replace
restore
 
* use imputed data
use mit_white, clear
append using miu_white 
capture drop _merge 
duplicates drop 

* add higher order terms of imputed variables that were in original PS model
capture drop dbp2 
gen dbp2_i=dia_bp_i^2

* recheck exclusion criteria that contains BP and SCr values: BP>160/100, SCr>265, SBP<90
drop if sys_bp_i>160 & dia_bp_i>100
drop if SCr_i>265
drop if sys_bp_i<90

xi: mim: logistic exposed i.stroke_TIA_i i.DM_prior_i i.PAD_any_i c.ageAtPeriod_i i.DM_comps_i i.CAD_any_i i.smokstatus_i i.bmicat_i i.sex_i i.statin_i i.nitrate_i i.DM_treatment_i i.diuretic_i i.ccb_i i.betablocker_i i.aspirin_i i.alphablocker_i i.antiplatelet_i i.oac_i i.imd_5_i  c.hospln_i c.year_i sys_bp_i dia_bp_i c.timesince_i c.aceicounter_i c.arbln_i c.GP_apt_i c.SCr_i c.aceicounter2_i c.timesince2_i c.age2_i c.dbp2_i

* cannot use predict to obtain probabilities after logistic regression as normally would so instead do the following and transform into predicted probability
mim: predict lpi, xb 
gen pi= exp(lpi)/(1+exp(lpi))

drop if pi==.

* check distribution 
bysort exposed: summ pi, detail

twoway (hist pi if treatment=="ARB", color(navy%50) lcolor(navy%50) lwidth(vthin) fcolor(navy%50)) (hist pi if treatment=="ACEi",  color(maroon%50) lcolor(maroon%50) lwidth(vthin) fcolor(maroon%50)), legend(label(1 "ARB") label(2 "ACEi")) xtitle("Propensity score")

* cut at lowest pscore in treated and highest pscore in untreated (1%)
summ pi if exposed==1, detail
gen p1=r(p1)

summ pi if exposed==0, detail 
gen p99=r(p99)

drop if pi<p1 | pi>p99

drop p1 p99

* check distribution after trimming 
bysort exposed: summ pi, detail

twoway (hist pi if treatment=="ARB", color(navy%50) lcolor(navy%50) lwidth(vthin) fcolor(navy%50)) (hist pi if treatment=="ACEi",  color(maroon%50) lcolor(maroon%50) lwidth(vthin) fcolor(maroon%50)), legend(label(1 "ARB") label(2 "ACEi")) xtitle("Propensity score")

* generate inverse-probability prweights
gen wt=1/pi if exposed==1
replace wt=1/(1-pi) if exposed==0

* check distribution of weights
bysort exposed: summ wt

save "${datadir}/sensitivity/MI/mi_white_all", replace

* check balance after weighting
egen sumofweights = total(wt)
gen norm_weights  = wt/sumofweights

xi: mpbalchk exposed i.stroke_TIA_i i.DM_prior_i i.PAD_any_i c.ageAtPeriod_i i.DM_comps_i i.CAD_any_i i.smokstatus_i i.bmicat_i i.sex_i i.statin_i i.nitrate_i i.DM_treatment_i i.diuretic_i i.ccb_i i.betablocker_i i.aspirin_i i.alphablocker_i i.antiplatelet_i i.oac_i i.imd_5_i  c.hospln_i c.year_i sys_bp_i dia_bp_i c.timesince_i c.aceicounter_i c.arbln_i c.GP_apt_i c.SCr_i c.aceicounter2_i c.timesince2_i c.age2_i c.dbp2_i, wt(norm_weights) graph



