**** DO-FILE TO GENERATE PS USING PS MODEL FOR PATIENTS OF WHITE ETHNICITY ****

/* From DAG potential vars:
Self-reported ethnicity - eth5
sex - sex
BP - sys_bp, dia_bp
Age- age
smoking_alcohol - smoke_status, alcohol_status
previous medical history - Angina, MI, stroke_TIA, int_claud (intermittent claudication), PAD_any, CAD_any, DM_high_risk
BMI - bmi
diabetes - diabetes
other treatment - statin, nitrate, DM_treatment, diuretic, digoxin, ccb, betablocker, aspirin, antiplatelet, anticoag
calendar period - year
healthcare utilisation - hosp_admi (no. of hosp. admissions)  GP_apt (no. of GP appointments) 
SES - imd2015_5 (index of multiple deprivation)
*/

*************** STEP 1: PREPARE DATASET *********************

* append ARB and ACEi trial eligible periods 
use "${datadir}\Tial_eligible_periods_ACEi.dta", clear
gen treatment="ACEi"
gen exposed=1

append using "${datadir}\Trial_eligible_periods_ARB.dta"
replace treatment="ARB" if treatment==""
replace exposed=0 if exposed==.

*** merge on dataset to keep random period per patient only ***
merge m:1 ptid rxst exposed using "${datadir}\1 PERIOD PER PT - RANDOM\random_period.dta", keep(match) nogen
	
*** merge on time related variables
merge m:1 ptid rxst treatment using "${datadir}\timerelated_vars.dta", keep(match) nogen

* check no. of events in each category is at least 10% of total events if not omit and check balance
* check missingness if substantial and cannot assume MAR omit and check balance
tab treatment

local varlist stroke_TIA DM_prior PAD_any sex DM_comps CAD_any smokstatus statin nitrate DM_treatment diuretic digoxin ccb betablocker aspirin antiplatelet oac alphablocker alcstatus imd_5

foreach var of local varlist {
	tab exposed `var', missing
}

*** WHITE ETHNICITY ONLY ***
keep if eth4==0

** missing indicator for serum creatinine
gen SCr_nmiss=1 if SCr!=.
replace SCr_nmiss=0 if SCr==.
gen SCr_new=SCr 

* check distribution of creatinine
hist SCr 

* replace SCr with mean within group if missing 
summ SCr if exposed==0
replace SCr_new=r(mean) if exposed==0 & SCr==.
summ SCr if exposed==1
replace SCr_new=r(mean) if exposed==1 & SCr==.

*************** STEP 2: BUILD PS MODEL *********************

* Include all continuous forms initially. Age, BP and BMI, year, hosp_ami, GP_apt, SCr
* check linearity if shows departure use transformation
* If categorical form is meaningful (age, bmi, year, BP) check if continuous or categorical form results in a better model fit

logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus c.bmi i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hosp_admi c.year sys_bp dia_bp c.timesince c.aceicounter c.arbcounter c.GP_apt  i.SCr_nmiss c.SCr_new

est store A

* Check functional form of continuous variables

************** Year *****************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog year

* Create categorical variable 
egen yearcat=cut(year), group(4)
label define yearcatn 0 "2001-2003" 1 "2004-2006" 2 "2007-2009" 3 "2010-2019" 
label values yearcat yearcatn
tab exposed yearcat

* Test if categorical form is preferred
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus c.bmi i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hosp_admi i.yearcat sys_bp dia_bp c.timesince c.aceicounter c.arbcounter c.GP_apt  i.SCr_nmiss c.SCr_new
est store B

lrtest A B 

************** Age *****************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog ageAtPeriod

* Categorise in 10 year bans up to 75
egen Agecat=cut(ageAtPeriod), at(54, 65, 75, 107)
recode Agecat (54=1) (65=2) (75=3) 
label define agecatn3 1 "55-65" 2 "65-75" 3 "75+" 
label values Agecat agecatn3
tab exposed Agecat

* Test if categorical form is preferred
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any i.Agecat i.DM_comps i.CAD_any i.smokstatus c.bmi i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hosp_admi c.year sys_bp dia_bp c.timesince c.aceicounter c.arbcounter c.GP_apt  i.SCr_nmiss c.SCr_new
est store B

lrtest A B 

************** BMI *****************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog bmi

* Categorise BMI based on NHS categorisation of healthy, overweight and obsese
egen bmicat=cut(bmi), at(4, 25, 30, 102)
recode bmicat (4=1) (25=2) (30=3) 
label define bmicatn 1 "healthy: <25" 2 "overweight: 25-30" 3 "obsese: 30+" 
label values bmicat bmicatn

* Test if categorical form is preferred
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hosp_admi c.year sys_bp dia_bp c.timesince c.aceicounter c.arbcounter c.GP_apt  i.SCr_nmiss c.SCr_new
est store B

lrtest A B  

******** systolic BP ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog sys_bp

* Categorise BP
egen sysbpcat=cut(sys_bp), at(78, 120, 130, 140, 240)
recode sysbpcat (78=1) (120=2) (130=3) (140=4)
label define sysbpcatn 1 "Normal BP" 2 "Elevated BP" 3 "High BP 1" 4 "High BP 2"
label values sysbpcat sysbpcatn 
tab exposed sysbpcat

* Test if categorical form is preferred
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hosp_admi c.year i.sysbpcat dia_bp c.timesince c.aceicounter c.arbcounter c.GP_apt  i.SCr_nmiss c.SCr_new
est store B

lrtest A B 
 
******** diastolic BP ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog dia_bp

* Categorise BP
egen diabpcat=cut(dia_bp), at(29, 80, 90,201)
recode diabpcat (29=1) (80=2) (90=3)
label define diabpcatn 1 "Normal BP" 2 "High BP 1" 3 "High BP 2"
label values diabpcat diabpcatn 
tab exposed diabpcat

* Test if categorical form is preferred
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hosp_admi c.year c.sys_bp i.diabpcat c.timesince c.aceicounter c.arbcounter c.GP_apt  i.SCr_nmiss c.SCr_new
est store B

lrtest A B

******** No. of hospital admissions ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog hosp_admi 

* log transformation 
gen hospln=log(hosp_admi+1)

logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbcounter c.GP_apt  i.SCr_nmiss c.SCr_new
est store A

* Check linearity assumption with transformed variable
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog hospln 

******** Time since 1st eligible period ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog timesince

******** No. of prior ACEi eligible periods ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog aceicounter

******** No. of prior ARB eligible periods ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog arbcounter  

* quadratic transform
gen arbcounter2=arbcounter^2 

logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbcounter c.arbcounter2 c.GP_apt  i.SCr_nmiss c.SCr_new
est store A

* check linearity assumption with transformed variable
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog arbcounter2 

* log transformation
gen arbln=log(arbcounter+1)

logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new
est store A

* check linearity assumption with transformed variable
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog arbln 


******** No. of GP appointments ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog GP_apt

******** Serum creatinine ******************
* Check linearity assumption using lowess plot
capture drop pr_prog
predict pr_prog, rstand
lowess pr_prog SCr_new


* Check higher order terms

logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new

est store A

** Age 
gen age2=ageAtPeriod^2 
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new c.age2

est store B
lrtest A B 

** systolic BP
gen sbp2=sys_bp^2 
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new c.sbp2
est store B

lrtest A B 

** diastolic BP
gen dbp2=dia_bp^2 
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_newc.dbp2
est store B

lrtest A B 

** time since first eligible period
gen timesince2=timesince^2 
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new c.timesince2
est store B

lrtest A B 

** no. of previous ACEi periods 
gen aceicounter2=aceicounter^2 
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new c.aceicounter2
est store B
 
lrtest A B 

** Serum creatinine
gen scr2=SCr_new^2 
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_neww c.scr2
est store B
 
lrtest A B 

** no. of GP appointments
gen GP2=GP_apt^2 
logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new c.GP2
est store B
 
lrtest A B 

* Test all significant higher order terms in combination 

logistic exposed i.stroke_TIA i.DM_prior i.PAD_any c.ageAtPeriod i.DM_comps i.CAD_any i.smokstatus i.bmicat i.sex i.statin i.nitrate i.DM_treatment i.diuretic i.ccb i.betablocker i.aspirin i.alphablocker i.antiplatelet i.oac i.imd_5  c.hospln c.year sys_bp dia_bp c.timesince c.aceicounter c.arbln c.GP_apt  i.SCr_nmiss c.SCr_new c.aceicounter2 c.timesince2 c.dbp2 c.age2 

* all significant 

* save dataset containing variables in included in propensity score model
save "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_ps_model_vars_white.dta", replace

* predict propensity score and drop missing propensity scores
predict pscore
drop if pscore==.

* check distribution 
bysort exposed: summ pscore, detail

twoway (hist pscore if treatment=="ARB", color(navy%50) lcolor(navy%50) lwidth(vthin) fcolor(navy%50)) (hist pscore if treatment=="ACEi",  color(maroon%50) lcolor(maroon%50) lwidth(vthin) fcolor(maroon%50)), legend(label(1 "ARB") label(2 "ACEi")) xtitle("Propensity score")

* cut at lowest pscore in treated and highest pscore in untreated (1%)
summ pscore if exposed==1, detail
gen p1=r(p1)

summ pscore if exposed==0, detail 
gen p99=r(p99)

drop if pscore<p1 | pscore>p99

drop p1 p99

* check distribution after trimming 
bysort exposed: summ pscore, detail

twoway (hist pscore if treatment=="ARB", color(navy%50) lcolor(navy%50) lwidth(vthin) fcolor(navy%50)) (hist pscore if treatment=="ACEi",  color(maroon%50) lcolor(maroon%50) lwidth(vthin) fcolor(maroon%50)), legend(label(1 "ARB") label(2 "ACEi")) xtitle("Propensity score")

* generate inverse probability weights
gen wt=1/pscore if exposed==1
replace wt=1/(1-pscore) if exposed==0

* check distribution of weights
bysort exposed: summ wt

* save for South Asian population
save "${datadir}\1 PERIOD PER PT - RANDOM\ACEi_ARB_PS_WHITE.dta", replace
