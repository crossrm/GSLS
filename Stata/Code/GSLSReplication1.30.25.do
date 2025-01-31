***********************************************************
***********************************************************
** GSLS method illustration
** Goal: 	Replicate results in "Removing collinearity while keeping interpretability"
** Inputs:	User settings (see options below)
**			File - Mother characteristics and household income - incomeAFQT.csv
**			File - Child characteristics and test scores - peabodyPIATreadingcomp.csv
** Outputs: Summary table (1) 
**			OLS/GSLS comparison table (2)
**			Income figure (2)
**			Intermediate regression results table (3)
**			Covariate matching results tables (4)-(5)
** Written: robin m cross, 2.12.19
** Updated: Matching section 6.29.19 AW
** 			GSLS illustration 9.2.21 RC
** 			For simultaneous spousal block 11.8.21 RC
** 			Release draft 2.3.22 RC
** 			Causal inference 7.23.24 RC
** 			Release draft 1.30.25 RC
***********************************************************
***********************************************************

***********************************************************
** Data prep, general settings, initial installations
***********************************************************
scalar prep = 1
if prep == 1 {

	***********************************************************
	** Install packages (if needed set inst scalar to 1)
	***********************************************************
	scalar inst = 0 
	if inst == 1 {
		
		** Stats command
		ssc install univar
		
		** Margins plot option 1 -- color
		ssc install g538schemes, replace all
			*help 538
			
		** Margins plot option 2 -- article
		scalar article_format = 1
		if article_format == 1 {

			capture noisily net install http://www.stata-journal.com/software/sj18-3/gr0073/
			ssc install grstyle, replace
			ssc install palettes, replace
			ssc install colrspace, replace

		} //End if
		di "Done with graph install."

	} //End if
	di "Done with packages install."

	***********************************************************
	** General settings
	***********************************************************
	scalar set = 1 
	if set == 1 {
		
		clear all
		*local myfolder = "C:\data\GSLS\stata\" //Set your default drive here
		*cd `mydrive'
		clear matrix
		set matsize 11000, permanently
		set maxvar 32767, permanently
		*set niceness 6
		set max_memory 80g
		set segmentsize 96m  //for large memory computers
		set min_memory 0
		set more off, permanently
		set scrollbufsize 300000
		
		** Margins plot fomat - Figure 2 Income
		scalar article_format = 1
		if article_format == 1 {

			*Graph Settings
			grstyle clear
			set scheme s2color
			grstyle init
			grstyle set plain, box nogrid
			grstyle color background white
			grstyle set color Set1
			grstyle init
	*		grstyle set plain, nogrid noextend
			grstyle yesno draw_major_hgrid no //yes
			grstyle yesno draw_major_ygrid no //yes
			grstyle color major_grid gs8
			grstyle linepattern major_grid dot
			grstyle set legend 4, box inside
			grstyle color ci_area gs12%50
			grstyle set nogrid		
			
		} //End if
		di "Done with graph settings."
		
	} //End if
	di "Done with general settings."

	***********************************************************
	** Load and prep mom household income
	***********************************************************
	scalar load = 1 
	if load == 1 {
		
		cd_StataData
		import delimited incomeAFQT.csv, clear

		** Rename
		renvars *, upper

		rename R0000100 momid 
		rename R0173600 SAMPLE_ID_1979 
		rename R0214700 momrace
		rename R0214800 momsex 

		rename R0618200 AFQT_1_1981 // AFQT-1
		rename R0618300 AFQT_2_1981 // AFQT-2
		rename R0618301 AFQT_3_1981 // AFQT-3

		rename R0190310 TNFI_HHI_TRUNC_1979 
		rename R0217900 TNFI_TRUNC_1979 
		rename R0406010 TNFI_TRUNC_1980 
		rename R0618410 TNFI_TRUNC_1981 
		rename R0898600 TNFI_TRUNC_1982 
		rename R1144500 TNFI_TRUNC_1983 
		rename R1519700 TNFI_TRUNC_1984 
		rename R1890400 TNFI_TRUNC_1985 
		rename R2257500 TNFI_TRUNC_1986 
		rename R2444700 TNFI_TRUNC_1987 
		rename R2870200 TNFI_TRUNC_1988 
		rename R3074000 TNFI_TRUNC_1989 
		rename R3400700 TNFI_TRUNC_1990 
		rename R3656100 TNFI_TRUNC_1991 
		rename R4006600 TNFI_TRUNC_1992 
		rename R4417700 TNFI_TRUNC_1993 
		rename R5080700 TNFI_TRUNC_1994 
		rename R5166000 TNFI_TRUNC_1996 
		rename R6478700 TNFI_TRUNC_1998 
		rename R7006500 TNFI_TRUNC_2000 
		rename R7703700 TNFI_TRUNC_2002 
		rename R8496100 TNFI_TRUNC_2004 
		rename T0987800 TNFI_TRUNC_2006 
		rename T2210000 TNFI_TRUNC_2008 
		rename T3107800 TNFI_TRUNC_2010 
		rename T4112300 TNFI_TRUNC_2012 
		rename T5022600 TNFI_TRUNC_2014 
		rename T5770800 TNFI_TRUNC_2016 
		rename T8218700 TNFI_TRUNC_2018 

		renvars *, lower
		drop *_hhi_* 
		order *, alpha
		order momid* sample*

		rename *_trunc_* *_*
		 
		** Dups
		duplicates list momid 
		compress

		** Save (1979 weighted sample)
		cd_StataStage
		save prep_mom_NLSY, replace
		
		** Update survey weighted to 1991
		scalar weight91 = 1
		if weight91 == 1 {
			
			** Load
			cd_StataStage
			use prep_mom_NLSY, clear
			
			** Determine if income entries are all blank after 1991
			gen income_check		= 0
			drop sample_id_1979-tnfi_1991
			
			** Income loop
			foreach var of varlist tnfi_* {
				
				replace `var' 	= 0 if `var' < 0
				
				replace income_check = income_check + `var'
				
			} //End loop
			di "Done with income loop."
			
			keep if income_check > 0
			keep momid
			duplicates drop
			
			** Join mother data and drop
			cd_StataStage
			joinby momid using prep_mom_NLSY, unmatch(master)
				tabulate _merge
			drop _merge

			** Save Update to 1991 reweighted sample
			cd_StataStage
			save prep_mom_NLSY, replace

		} //End if
		di "Done with 1991 weights"
		
	} //End if
	di "Done with load income."

	***********************************************************
	** Load and prep child tests
	***********************************************************
	scalar load = 1 
	if load == 1 {
		
		cd_StataData
		import delimited peabodyPIATreadingcomp.csv, clear

		** Rename
		rename c0000100 cPUBID 
		rename c0000200 momid 

		** Demog
		rename c0005300 cRAcE 
		rename c0005400 cSEX 
		rename c0005500 cMOB 
		rename c0005700 cYRB 
		rename c0005701 cMODEATH 
		rename c0005702 cYRDEATH
		rename c0007000 MAGEBIR 		//mom age at birth

		** Previous years
		rename c0054101 HGcREV1980_1980 
		rename c0057501 HGcREV1982_1982 
		rename c0058701 HGcREV1984_1984 
		rename c0059901 HGcREV1986_1986 
		rename c0061100 HGcDOI1988_1988 
		rename c0061112 HGcDOI1990_1990 
		rename c0061116 HGcDOI1992_1992 
		rename c0061120 HGcDOI1994_1994 
		rename c0061122 HGcDOI1996_1996 
		rename c0061124 HGcDOI1998_1998 
		rename c0061126 HGcDOI2000_2000 
		rename c0061128 HGcDOI2002_2002 
		rename c0061130 HGCDOI2004_2004 
		rename c0061132 HGCDOI2006_2006 
		rename c0093100 SPOUSE1980_1980 
		rename c0093110 AGESPS1980_1980 
		rename c0093200 HGCSPS1980_1980 
		rename c0093800 NFAMEM1980_1980 
		rename c0099300 SPOUSE1982_1982 
		rename c0099310 AGESPS1982_1982 
		rename c0099400 HGCSPS1982_1982 
		rename c0100000 NFAMEM1982_1982 
		rename c0105500 SPOUSE1984_1984 
		rename c0105510 AGESPS1984_1984 
		rename c0105600 HGCSPS1984_1984 
		rename c0106200 NFAMEM1984_1984 
		rename c0111700 SPOUSE1986_1986 
		rename c0111710 AGESPS1986_1986 
		rename c0111800 HGCSPS1986_1986 
		rename c0112400 NFAMEM1986_1986 
		rename c0119400 NFAMEM1988_1988 
		rename c0120000 SPOUSE1988_1988 
		rename c0120010 AGESPS1988_1988 
		rename c0120100 HGCSPS1988_1988 
		rename c0125800 NFAMEM1990_1990 
		rename c0126400 SPOUSE1990_1990 
		rename c0126500 AGESPS1990_1990 
		rename c0126600 HGCSPS1990_1990 
		rename c0127617 NFAMEM1992_1992 
		rename c0127623 SPOUSE1992_1992 
		rename c0127624 AGESPS1992_1992 
		rename c0127625 HGCSPS1992_1992 
		rename c0127917 NFAMEM1994_1994 
		rename c0127923 SPOUSE1994_1994 
		rename c0127924 AGESPS1994_1994 
		rename c0127925 HGCSPS1994_1994 
		rename c0128017 NFAMEM1996_1996
		rename c0128023 SPOUSE1996_1996
		rename c0128024 AGESPS1996_1996 
		rename c0128025 HGCSPS1996_1996
		rename c0580600 COMPP1986_1986 
		rename c0800100 COMPP1988_1988 
		rename c0999300 COMPP1990_1990 
		rename c1199300 COMPP1992_1992 
		rename c1508300 COMPP1994_1994 
		rename c1565200 COMPP1996_1996 

		rename c1800600 COMPP1998_1998 
		rename c1988000 NFAMEM1998_1998 
		rename c1988500 SPOUSE1998_1998 
		rename c1988600 AGESPS1998_1998 
		rename c1988700 HGCSPS1998_1998 
		
		rename c2504200 COMPP2000_2000 
		rename c2494000 NFAMEM2000_2000 
		rename c2494500 SPOUSE2000_2000	 
		rename c2494600 AGESPS2000_2000 
		rename c2494700 HGCSPS2000_2000 
		
		rename c2521800 NFAMEM2002_2002 
		rename c2522300 SPOUSE2002_2002 
		rename c2522400 AGESPS2002_2002 
		rename c2522500 HGCSPS2002_2002 
		rename c2532700 COMPP2002_2002 
		
		rename c2792300 NFAMEM2004_2004 
		rename c2792800 SPOUSE2004_2004 
		rename c2792900 AGESPS2004_2004 
		rename c2793000 HGCSPS2004_2004 
		rename c2803500 cOMPP2004_2004 
		
		rename c3101800 NFAMEM2006_2006 
		rename c3102300 SPOUSE2006_2006 
		rename c3102400 AGESPS2006_2006 
		rename c3102500 HGcSPS2006_2006 
		rename c3112000 cOMPP2006_2006 
		rename c3602400 HGcDOI2008_2008 
		rename c3604100 NFAMEM2008_2008 
		rename c3604600 SPOUSE2008_2008 
		rename c3604700 AGESPS2008_2008 
		rename c3604800 HGcSPS2008_2008 
		rename c3615700 cOMPP2008_2008 
		rename c3982400 HGcDOI2010_2010 
		rename c3984100 NFAMEM2010_2010 
		rename c3984600 SPOUSE2010_2010 
		rename c3984700 AGESPS2010_2010 
		rename c3984800 HGcSPS2010_2010 
		rename c3994300 cOMPP2010_2010 
		rename c5526200 HGcDOI2012_2012 
		rename c5528000 NFAMEM2012_2012 
		rename c5528500 SPOUSE2012_2012 
		rename c5528600 AGESPS2012_2012 
		rename c5528700 HGcSPS2012_2012 
		rename c5538300 cOMPP2012_2012 
		rename c5802500 HGcDOI2014_2014 
		rename c5804300 NFAMEM2014_2014 
		rename c5804800 SPOUSE2014_2014 
		rename c5804900 AGESPS2014_2014 
		rename c5805000 HGcSPS2014_2014 
		rename c5814100 cOMPP2014_2014 
		rename y3299900 Q15_142_2014 // Q15-142

		renvars *, lower
		drop q15* //*_raw *_std //csage86_mo

		** Order
		order *, alpha 
		order cpubid momid crace csex cyrb cyrdeath cmodeath cmob magebir

		** Dups
		duplicates list cpubid 
		compress

		** Save
		cd_StataStage
		save prep_child_NLSY, replace
		
	} //End if
	di "Done with load supplement."

	***********************************************************
	** Join tests with income
	***********************************************************
	scalar load = 1 
	if load == 1 {
		
		** Load child tests
		cd_StataStage
		use prep_child_NLSY, clear
		
		** Erase
		cd_StataStage
		//erase prep_child_NLSY.dta
				
		** Join
		joinby momid using prep_mom_NLSY, unmatched(master)
			tabulate _merge
		drop if _merge == 1	
		drop _merge

		** Erase 
		cd_StataStage
		//erase prep_mom_NLSY.dta
		
		** Clean
		drop sampl*
		
		** Drop missing afqt results
		drop afqt_1_1981 afqt_3_1981
		drop if afqt_2_1981<0 
		rename afqt_2_1981 momtest
		
		** Order
		order cpubid momid crace csex cyrb cyrdeath cmodeath cmob ///
			magebir momrace momsex momtest
			
		** Loop consistent naming
		rename hgcrev* hgcdoi*
		
		** Save
		cd_StataStage
		save merged_NLSY, replace
		
	} //End if
	di "Done with join."

	***********************************************************
	** Obtain child's first test attempt
	***********************************************************
	scalar first = 1
	if first == 1 {
		
		** Loop to create all test observations
		local k = 1 //Count variable
		quietly foreach y of numlist 1986(2)2014 {
		
			** Load			
			cd_StataStage
			use merged_NLSY, clear 
			
			** Gen ages
			gen childage		= `y' - cyrb 			//Child age years -- use months in reg 
			gen mage			= childage + magebir		//Mothers age at test 1986
			
			** Gen year for CPI
			gen year			= `y'
			
			** Rename variables of interest
			rename compp`y'_`y' 	test_pcntl
			rename spouse`y'_`y' 	spouse_yn
			rename agesps`y'_`y'	spouse_age
			rename hgcsps`y'_`y'	spouse_grade
			rename nfamem`y'_`y'	family_size
			rename hgcdoi`y'_`y'	mom_grade
			* Income
			rename tnfi_`y'			fincome
					
			** Keep complete records
			quietly drop if spouse_yn < 0
			quietly drop if test_pcntl < 0
			
			** Replace spouse info for no-spouse case
			quietly replace spouse_age 		= 0 if spouse_age == -7
			quietly replace spouse_grade	= 0 if spouse_grade == -7

			** Keep relevant data
			order cpubid momid test_pcntl year momrace mage mom_grade momtest ///
				spouse_yn spouse_age spouse_grade ///
				crace csex childage ///
				family_size fincome 
			
			keep cpubid-fincome
			
			** Save
			if `y' == 1986 {
				
				** Save
				cd_StataStage
				save tests_NLSY, replace
				
			} //End if
			di "Done with first save."
			else {

				** Append
				cd_StataStage
				append using tests_NLSY
				
				** Save
				cd_StataStage
				save tests_NLSY, replace
				
			} //End else
			di "Done with save."
						
		} //End loop
		di "Done with data creation loop."
		
		** Erase
		cd_StataStage
		//erase tests_NLSY.dta
		//erase merged_NLSY.dta
		
		** Keep first test record - duplicates drop keeps first, so order reverse chron.
		gen n						= _n
		gsort -n
		duplicates drop cpubid, force
		drop n

		** Keep child age range
		keep if childage <= 14 & childage >= 6

		** Variable drop loop
		foreach var of varlist * {
			
			quietly drop if `var' < 0
			
		} //End loop
		di "Done with income records loop."

		** Save
		cd_StataStage
		save prep_data_NLSY, replace

		**************************************
		** Adjust income for CPI
		**************************************
		** Format CPI data
		cd_StataData
		import delimited CPI_index.csv, clear
		cd_StataStage
		save CPI_index.dta, replace
		
		** Reload
		cd_StataStage
		use prep_data_NLSY, clear
		
		** Join
		cd_StataStage
		joinby year using CPI_index, unmatched(master)
			tabulate _merge
		drop _merge
		** Adjust
		replace fincome			= fincome * index
		drop cpi base2020 index
		
		** Erase
		cd_StataStage
		//erase CPI_index.dta		
		
		** Save
		cd_StataStage
		save prep_data_NLSY, replace
		
	} //End if
	di "Done with data loop."
	 
	***********************************************************
	** Table 2 NSLY Summary statistics
	** Print mom and child count included in study
	** Prep data for regression
	***********************************************************
	scalar sum = 1
	if sum == 1 {
		
		** Load
		cd_StataStage
		use prep_data_NLSY, clear 
		
		** Erase
		cd_StataStage
		*erase prep_data_NLSY.dta
		
		** Set income preference (log income = 1)
		scalar ln = 1
		
		** Indicators
		quietly tabulate momrace, generate(momrace)
		drop momrace
		drop momrace3	//momrace3 is White, 1 Black, 2 Hispanic
			
		foreach var of varlist crace csex {
			
			quietly tabulate `var', generate(`var')
			drop `var'
			drop `var'1
			
		} //End loop
		di "Done with indicators loop."
		
		** Scale income to 10K
		replace fincome		= fincome / 10000
		
		** Income stats
		if ln == 1 {
			
			drop if fincome <= 0
			
		} //End if
		di "Done with zero income drop."
		
		** Print summary stats
		** Percentile split
		xtile hincome 					= fincome, nquantiles(2)
		replace hincome					= hincome - 1
		sort hincome fincome
		by hincome: summarize *
		drop hincome
		
		** Print mom, child counts used in illustration
		codebook momid cpubid, compact
		
		***********************************************
		** Data prep for regression section
		***********************************************
		** More indicators
		foreach var of varlist year {
			
			quietly tabulate `var', generate(`var')
			drop `var'
			drop `var'1
			
		} //End loop
		di "Done with indicators loop."
		
		** Transforms
		replace family_size 			= log(family_size)
		if ln == 1 {
			replace fincome			= log(fincome)
		} //End if
		di "Done with transforms."
			
		** Drop variables (perfect colinearity)
		drop crace*		//perfectly collinear with momrace - NLSY did not distinguish
		
		 ** Order
		 order test_pcntl year* momrace* mage mom_grade momtest spouse_* ///
			csex* childage family_size fincome
			 
		** Save Stata file
		cd_StataStage
		save run_data_NLSY, replace
		
		** Output csv file
		cd_StataStage
		outsheet using GSLS_NLSY_data.csv, replace
		
	} //End if 
	di "Done with data prep."
	
} //End if
di "Done with data prep. Ready to run model."

***********************************************************
** Treatment prep
***********************************************************
scalar cause = 1
if cause == 1 {
	
	** Load
	cd_StataStage
	use run_data_NLSY, clear
	
	** Gen race treatment variable - nonwhite
	gen nonwhite				= momrace1 + momrace2
	drop momrace*
	
	** Gen income treatment variable
	** Gen treatment variables from income
	xtile hincome 					= fincome, nquantiles(2)
	replace hincome					= hincome - 1
	drop fincome
	
	** Keep
	order cpubid momid ///
		nonwhite ///
		mage  ///
		mom_grade ///
		momtest ///
		csex* ///
		childage ///
		year* ///
		spouse_* /// 
		family_size ///
		hincome ///
		test_pcntl
		
	keep cpubid-test_pcntl
	
	** Save
	cd_StataStage
	save GSLS_ready, replace
	
} //end if
di "Done with causal OLS."

***********************************************************
** Extended GSLS
***********************************************************
scalar decor = 1
if decor == 1 {
	
	** Load
	cd_StataStage
	use GSLS_ready, clear
	
	** Order data 	// Order chronologically, group simultaneous variables
	order cpubid momid ///
		nonwhite ///
		mage  ///
		mom_grade ///
		momtest ///
		csex* ///
		childage ///
		year* ///
		spouse_* /// 
		family_size ///
		hincome ///
		test_pcntl
		
	** Name controls and independent variable
	eststo clear
	eststo: reg test_pcntl nonwhite-hincome, vce(robust) nostar
	
	** Suffix data 	- Assign conscutive numbers, sim = simultaneous blocks, seq for sequential blocks
	** Note:		- If block 0 covariates are sequential, include only the first in block 0.
	**				- If block 0 covariates are simultaneous, include all.

	scalar suffix = 1 
	if suffix == 1{
		
		** Block one is also simultaneous - name sim 1:
		rename 		nonwhite		nonwhite_sim0

		** Block zero is a simultaneous block - name sim 0:
		rename 		year* 			year*_seq1
		
		** Block two consists of sequential covariates - name seq 2:
		rename 		mage			mage_seq2
		rename 		mom_grade		mom_grade_seq2
		rename		momtest			momtest_seq2
		
		** Block three is simultaneous - name sim 3:
		rename 		spouse_yn		spouse_yn_sim3
		rename 		spouse_age		spouse_age_sim3
		rename 		spouse_grade	spouse_grade_sim3
		
		** Block four includes the remaining sequential covariates - name seq 4:
		rename 		csex2			csex2_seq4
		rename 		childage		childage_seq4
		rename 		family_size		family_size_seq4
		rename 		hincome			hincome_seq4

	} //End if
	di "Done with suffix blocks."
	
	** Set covaraiate retention threshhold
	** Drops covariates explained (R^2) greater than stated tolerance
	** Set to 1.0 for no drops, 0.99 to drop when R^2 greater than 0.99
	scalar collin_tolerance		= 0.99	
	
	** Set results table print choice
	** Table 2 - (save_intermediate=0) Results table compares OLS direct effects to GSLS total effects
	** Table 3 - (save_intermediate=1) Intermediate regression results (all) - too large for some screen display
	scalar save_intermediate 	= 1
  	
	** Call Extended GSLS: 		GSLS0 	depvarname startblockno endblockno 
	**				example:	GSLS0  	test_pcntl 0 			4 
	*quietly 
	GSLS0 test_pcntl 0 4 
	
	** Store GSLS regression
	eststo: reg test_pcntl nonwhite-hincome, vce(robust) nostar
	
	** Print and save output
	esttab, nonumber se ar2 r2(a5) compress not nostar
	cd_StataResults
	esttab using GSLS_results_`save_intermediate'.csv, replace se r2(a5) nostar

	** Save decor data
	cd_StataStage
	save GSLS_decor_data_NLSY, replace

} //End if 
di "Done with GSLS."

***********************************************************
** Covariate matching
** Goal: 	Matches observations based on Mahalanobis covariate distance to find treatment effect
** Outputs: Average treatment effect of race and income upon treated (atet), 
**          covariate means before and after matching, 
**          standard differences in matched/unmatched covariate means
** written: aaron c kratzer, 02.12.19
** revised: ACK 			 06.28.19
** 			RMC				 09.07.21
**			RMC				 11.06.24
***********************************************************
scalar match = 1
if match == 1 {

	** Load OLS Pre-decor data
	cd_StataStage
	use GSLS_ready, clear				// Raw data
				
	** Set seed (optional)
	set seed 1102
	
	** Hetreg OLS - late treatment - higher income
	reg test_pcntl nonwhite-family_size hincome
	hettreatreg nonwhite-family_size, o(test_pcntl) t(hincome) 
	bootstrap att = e(att) atu = e(atu) ate = e(ate), reps(300) seed(1101): hettreatreg nonwhite-family_size, o(test_pcntl) t(hincome) 
		
	** Match - income - high income (treatment) vs low income (control)
	*ATET
	teffects nnmatch (test_pcntl nonwhite-family_size) (hincome), biasadj(nonwhite-family_size) generate(matches) atet
	drop matches*
	*ATE
	teffects nnmatch (test_pcntl nonwhite-family_size) (hincome), biasadj(nonwhite-family_size) generate(matches) ate
	tebalance summarize
	drop matches*
	
	** Hetreg OLS - early treatment - nonwhite
	reg test_pcntl nonwhite-family_size hincome
	hettreatreg mage-hincome, o(test_pcntl) t(nonwhite) 
	bootstrap att = e(att) atu = e(atu) ate = e(ate), reps(300) seed(1101): hettreatreg mage-hincome, o(test_pcntl) t(nonwhite) 
	
	** Match - race - white (treatment) vs non-white (control)
	*ATET
	teffects nnmatch (test_pcntl mage-hincome) (nonwhite), biasadj(mage-hincome) generate(matches) atet 
	** Show covariate standard differences after matching
	drop matches*
	
	** Match - race - white (treatment) vs non-white (control)
	*ATE
	teffects nnmatch (test_pcntl mage-hincome) (nonwhite), biasadj(mage-hincome) generate(matches) ate
	** Show covariate standard differences after matching
	tebalance summarize
	drop matches*
	
	** Load GSLS - Post-decor data
	** Estimate total effects
	** Load
	cd_StataStage
	use GSLS_decor_data_NLSY, clear
	
	** Hetreg OLS - early treatment - nonwhite
	reg test_pcntl nonwhite-family_size hincome
	hettreatreg mage-hincome, o(test_pcntl) t(nonwhite) 
	bootstrap att = e(att) atu = e(atu) ate = e(ate), reps(300) seed(1101): hettreatreg mage-hincome, o(test_pcntl) t(nonwhite) 
		
	
	** Match - race - white (treatment) vs non-white (control)
	*ATET
	teffects nnmatch (test_pcntl mage-hincome) (nonwhite), biasadj(mage-hincome) generate(matches) atet 
	** Show covariate standard differences after matching
	drop matches*
	
	** Match - race - white (treatment) vs non-white (control)
	*ATE
	teffects nnmatch (test_pcntl mage-hincome) (nonwhite), biasadj(mage-hincome) generate(matches) ate
	** Show covariate standard differences after matching
	tebalance summarize
	drop matches*
	
} //End if
di "Done with matching."

***********************************************************
** GSLS Angrist from Tymon Słoczynrsky 2022
** written: RMC 10.28.24
***********************************************************
local angrist = 1
if `angrist' == 1 {
	
	** Install
	*ssc install hettreatreg, all
	
	** process
	cd_StataData
	use nswcps, clear
	** rename
	rename treated job
	
	** Print summary stats
	gen white 				= (black==0 & hispanic == 0)
	order black white hispanic age educ nodegree married job re78
	sort job black
	by job: summarize *
	
	** Center
	//corr age* 
	sum age
	replace age = age - r(mean)
	replace age2 = age^2
	//corr age*
	//corr *
	
	** Keep
	order black age age2 educ nodegree married job re78
	keep black age age2 educ nodegree married job re78
	
	** Save
	cd_StataStage
	save prep_data_NSW, replace
	use prep_data_NSW, clear 
	
	** Initial reg
	eststo clear
	eststo: reg re78 black age age2 educ nodegree married job, nostar
	
	** Save OLS data
	cd_StataStage
	save OLS_angrist, replace
	
	** Name the groucps
	global simgroups "black age age2 educ nodegree married job"
		
	** Set counter
	local k						= 0
	foreach nam of global simgroups {
		
			di "Starting: `nam'."
		
		** Name group
		rename `nam' `nam'_sim`k'
		
		** Advance counter
		local k			= `k' + 1
		
	} //end loop
	di "Done with rename decor loop."
	local endblock = `k' - 1
	
	** Set covaraiate retention threshhold
	** Drops covariates explained (R^2) greater than stated tolerance
	** Set to 1.0 for no drops, 0.99 to drop when R^2 greater than 0.99
	scalar collin_tolerance		= 0.99
	
	** Set results table print choice
	** Table 2 - (save_intermediate=0) Results table compares OLS direct effects to GSLS total effects
	** Table 3 - (save_intermediate=1) Intermediate regression results (all) - too large for some screen display
	scalar save_intermediate	= 0
		
	** Call GSLS: 	GSLS0 depvarname startblockno 	endblockno 
	**	 example:	GSLS0 test_pcntl 0 				4 
	*quietly 
		di "Calling GSLS: depvar startblock `endblock' `save_intermediate'." 
	GSLS0 re78 0 `endblock'  
	
	** Save for display 
	eststo: reg re78 black-job, vce(robust)
	** Display	
		esttab, nonumber r2(a5) ar2 compress not

	** Save GSLS data
	cd_StataStage
	save GSLS_angrist, replace
	use OLS_angrist, clear
	
	** Hetreg OLS - early treatment - black
	reg re78 black age age2 educ nodegree married job
	hettreatreg age-job, o(re78) t(black)
	bootstrap att = e(att) atu = e(atu) ate = e(ate), reps(300) seed(1101): hettreatreg age-job, o(re78) t(black) 
	
	** Match - race - black (treatment) 
	*ATET
	teffects nnmatch (re78 age-job) (black), biasadj(age-job) generate(matches) atet 
	** Show covariate standard differences after matching
	drop matches*
	
	** Match - race - white (treatment) vs non-white (control)
	*ATE
	teffects nnmatch (re78 age-job) (black), biasadj(age-job) generate(matches) ate 
	** Show covariate standard differences after matching
	tebalance summarize
	drop matches*
	
	** Hetreg OLS - late treatment - jobs
	reg re78 black age age2 educ nodegree married job
	hettreatreg black-married, o(re78) t(job)
	bootstrap att = e(att) atu = e(atu) ate = e(ate), reps(300) seed(1101): hettreatreg black-married, o(re78) t(job) 
	
	** Match - job program
	*ATET
	teffects nnmatch (re78 black-married) (job), biasadj(black-married) generate(matches) atet 
	** Show covariate standard differences after matching
	drop matches*
	
	** Match - job program
	*ATE
	teffects nnmatch (re78 black-married) (job), biasadj(black-married) generate(matches) ate 
	** Show covariate standard differences after matching
	tebalance summarize
	drop matches*
		
	** GSLS Treatment effects	
	cd_StataStage
	use GSLS_angrist, clear
	
	** Hetreg GSLS - early treatment - black
	reg re78 black age age2 educ nodegree married job
	hettreatreg age-job, o(re78) t(black)
	bootstrap att = e(att) atu = e(atu) ate = e(ate), reps(300) seed(1101): hettreatreg age-job, o(re78) t(black) 
	
	** Match - race - black (treatment) 
	*ATET
	teffects nnmatch (re78 age-job) (black), biasadj(age-job) generate(matches) atet 
	** Show covariate standard differences after matching
	drop matches*
	
	** Match - race - white (treatment) vs non-white (control)
	*ATE
	teffects nnmatch (re78 age-job) (black), biasadj(age-job) generate(matches) ate 
	** Show covariate standard differences after matching
	tebalance summarize
	drop matches*	
			
} //end if
di "Done with GSLS angrist."
