***********************************************************
***********************************************************
** Extended Laplace program
** Goal: 	Replicate results in "Treatment effects without multicollinearity."
** Outputs: OLS/GSLS comparison table
**					-or-
**			Intermediate regression results table
** Written: robin m cross, 2.12.19
** Updated: Simultaneous blocks 11.8.21 RC
** 			Release draft 2.3.22 RC
***********************************************************
***********************************************************
capture program drop 	GSLS0
program define 			GSLS0

	*di "this is the right program asdf"
	*asdf
	
	** Read inputs
	local depvar 				= "`1'"
	local startblock		 	= "`2'"		
	local endblock				= "`3'"
	//local save_intermediate		= "`4'"		
					
	** List inputs
	while "`1'" != "" {
		
		di `"`1'"'
		mac shift
		
	} //End while
	di "Done with list."
	
	** Fix endpoint problem
	local endblock 				= `endblock' + 1
	
	****************************************
	** Center and drop zero variance
	****************************************
	scalar center = 1
	if center == 1 {
		
		** Omit starblock_name group
		
		** Gen filler vars
		cap gen _sim 			= 0
		cap gen _seq			= 0
	
		** Set controls
		local controls = "*_s*"
		
		** Begin drop zero variance loop
		local k = 0
		foreach var of varlist `controls' {
							
			** Drop zero variance
			quietly summarize `var' 
			local sig = r(sd)
			if `sig'==0 | `sig'==. {
			
				** Drop
				drop `var'
					di "Dropped `var' due to lack of variance `sig'."
					
			} //End if
			** Else, center
			else {
				
				** Center (after initial group)
				local mu			= r(mean)
				if `k' > 1 {
					
					//quietly replace `var' 		= `var' - `mu' //don't recenter to preserve binary early treatments
				
				} //end if
				di "Done with center - initial group check."
				
			} //End else
			di "			End check `var', std = `sig', mean = `mu'."
		
			** Advance counter
			local k = `k' + 1
		
		} //End loop
		di "Done with center and check variance loop."
	
	} //End if
	di "Done with center and drop."
	
	****************************************
	** Start Extended Laplace and save results
	****************************************
	scalar laplace = 1
	if laplace == 1 {
			
		** Call Extended Laplace
		** ext_laplace depvar startblock endblock save_intermediate //controls
		** e.g., ext_laplace test_pcntl 0 4 save_intermediate //`controls'
		
		** Convert save_intermediate flag to eststo prefix
		local int_prefix 		= ""
		local int_suffix		= ""
		** Indicate intermediate table to be saved
		if save_intermediate == 1 { 
			
			** Clear eststo - clears previous eststo activity
			eststo clear
			
			** Eststo prefix
			local int_prefix 	= "eststo: " 
			local int_suffix	= "nostar"
			
		} //End if	
		di "Done with set eststo prefix."
		
		** Decorr loop
		cap rename *_sim`startblock' *_sim`startblock'_d
		cap rename *_seq`startblock' *_seq`startblock'_d
		local first = `startblock' + 1
			di "Local start: `startblock', end: `endblock'."
			
		foreach num of numlist `first'/`endblock'    {

				di "Starting block `num'."

			** Simultaneous (sim) Sequential (seq) 
			global option "sim seq"
			cap noisily foreach op of global option {
		
					di "Starting option `op', block `num'."

				** Variables in block
				cap noisily foreach var of varlist *_`op'`num' {

						di "Starting var `var'."

					** Check for valid variable, then decor
					cap summarize *_`op'`num'
					if _rc == 0 {
						
							di "Running option `op', block `num', var `var'."
						
						** Reg and save intermediate results
						`int_prefix' 	reg `var' *_d  , vce(robust) `int_suffix'
						scalar check 		= e(r2)
							scalar list check collin_tolerance
					
						
						** Keep if R^2 above tolerance, else decorr
						if check > collin_tolerance {
							
							drop `var'
			
						} //End tolerance check
						di "Done with tolerance drop."
						else {

								di "Moving to decor `var'."
								
							** Decorr
							predict `var'_hat, xb
							replace `var' 	= `var' - `var'_hat
							drop `var'_hat
							
							** Rename if sequential variable-by-variable
							if "`op'" == "seq" {
							
									di "Renaming sequential variable `var'."
								** Raname sequential
								rename `var'	`var'_d

							} //End if
							di "Done with rename sequential."
													
						} //End if
						di "Done with decor step."
						
					} //End if
					di "Done with variable check and decor."
					
				} //End loop
				*di "Done with variables block."

				** Rename simultaneous blocks
				if "`op'" == "sim" {
					
						di "Renaming simultaneous variables block `num'."
					cap rename *_sim`num' *_sim`num'_d

				} //End if
				*di "Done with rename simultaneous block."

			} //End loop
			di "Done with Sim/seq option."
			
		} //End loop
		di "Done with group/num decor loop."
		
		** Reg and save final reg for intermediate results set
		** Store dependent variable reg
		`int_prefix' 	reg `depvar' *_d , vce(robust) `int_suffix'
						
		** Remove decor prefix
		rename *_d *
					
		** Loop restore names
		foreach num of numlist 0/`endblock' {
			
			capture rename *_sim`num' *
			capture rename *_seq`num' *
			
		} //End rename loop
		di "Done with rename loop."
		
		****************************************
		** Print intermediate tables
		****************************************
		if save_intermediate == 1 { 
			
			esttab, nonumber se r2(a5) compress 
			cd_wine
			esttab using laplace_results_save_intermediate.csv, replace
						
		} //End if	
		di "Done with set eststo prefix."
		
		** Clean up
		*drop ones
		
	*} //End if
	di "Done with Extended Laplace."
	
end
di "Program end."