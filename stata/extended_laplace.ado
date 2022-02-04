***********************************************************
***********************************************************
** Extended Laplace program
** Goal: 	Perform Extended Laplace regression as shown in "Removing collinearity while keeping interpretability"
** Inputs:	locals (described below)
** Outputs: OLS/Laplace comparison table (2)
**					-or-
**			Intermediate regression results table (3)
** Written: robin m cross, 2.12.19
** Updated: Simultaneous blocks 11.8.21 RC
** 			Release draft 2.3.22 RC
***********************************************************
***********************************************************
capture program drop 	extended_laplace
program define 			extended_laplace
	
	** Read inputs
	local depvar 				= "`1'"
	local startblock		 	= "`2'"		
	local endblock				= "`3'"
	local save_intermediate		= "`4'"		
	local myfolder				= "`5'"
			
	** List inputs
	while "`1'" != "" {
		di `"`1'"'
		mac shift
	} //End while
	di "Done with list."
	
	****************************************
	** Center and drop zero variance
	****************************************
	scalar center = 1
	if center == 1 {
		** Gen filler vars
		cap gen _sim 			= 0
		cap gen _seq			= 0
		
		** Set controls
		local controls *_sim* *_seq*
		
		** Begin loop
		foreach var of varlist `controls' {
							
			** Drop zero variance
			quietly summarize `var' 
			local sig = r(sd)
			if `sig'==0 | `sig'==. {
			
				drop `var'
					di "Dropped `var' due to lack of variance `sig'."
			} //End if
			** Else, center
			else {
				
				local mu			= r(mean)
				replace `var' 		= `var' - `mu'
			} //End else
			di "			End check `var', std = `sig', mean = `mu'."
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
		// ext_laplace depvar startblock endblock save_intermediate
		*ext_laplace test_pcntl 0 4 save_intermediate
		
		** Convert save_intermediate flag to eststo prefix
		local int_prefix 		= ""
		local comp_prefix		= ""
		if `save_intermediate' == 1 {
					
			** Eststo prefix
			local int_prefix 	= "eststo: " 
			
		} //End if			
		else {
			
			** Eststo prefix
			local comp_prefix 	= "eststo: "
			
		} //End else
		di "Done with set eststo prefix."
		
		** Save terminal regression OLS (direct effects)
		eststo clear
		** Reg - OLS linear
		`comp_prefix' 	reg test_pcntl* year* momrace* mage* mom_grade* momtest* spouse_* ///
				csex* childage* family_size* fincome* 
			
		** Decorr loop
		cap rename *_sim0 *_sim0_d
		cap rename *_seq0 *_seq0_d
		foreach num of numlist 1/4    {

				di "Starting block `num'."

			** Simultaneous (sim) Sequential (seq) 
			global option "sim seq"
			cap foreach op of global option {
		
					di "Starting option `op', block `num'."

				** Variables in block
				cap foreach var of varlist *_`op'`num' {

						di "Starting var `var'."

					** Check for valid variable, then decor
					cap summarize *_`op'`num'
					if _rc == 0 {
						
							di "Running option `op', block `num', var `var'."
						
						** Reg and save intermediate results
						`int_prefix' 	reg `var' *_d
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
				di "Done with variables block."

				** Rename simultaneous blocks
				if "`op'" == "sim" {
					
						di "Renaming simultaneous variables block `num'."
					cap rename *_sim`num' *_sim`num'_d

				} //End if
				di "Done with rename simultaneous block."

			} //End loop
			di "Done with Sim/seq option."
			
		} //End loop
		di "Done with group/num decor loop."
		
		** Reg and save final reg for intermediate results set
		** Store dependent variable reg
		`int_prefix' 	reg test_pcntl *_d
						
		** Remove decor prefix
		rename *_d *
					
		** Post decor reg for table
		** Reg decor data - linear
		`comp_prefix' 	reg test_pcntl year* momrace* mage* mom_grade* momtest* spouse_* ///
				csex* childage* family_size* fincome* 
		
		** Loop restore names
		foreach num of numlist 0/20 {
			
			capture rename *_sim`num' *
			capture rename *_seq`num' *
			
		} //End rename loop
		di "Done with rename loop."
		
	} //End if
	di "Done with Extended Laplace."
	
end
di "Program end."