# ---
# Title:    Extended Laplace program
# Goal: 	  Perform Extended Laplace regression as shown in "Removing collinearity while keeping interpretability"
# Inputs:	  locals (described below)
# Outputs:  Results list - OLS/Laplace comparison table (2)				
#			      Results list - Intermediate regression results table (3)
#           Orthogonalized covariate set - decor_data (list format)          
# Written:  robin m cross, 2.14.19
# Release:  2.16.22 RC
# ---

# Center - all variables - creates a matrix
run_data <- sapply(run_data, function(x) scale(x, scale=FALSE))

# Convert back to data frame
run_data <- as.data.frame(run_data)

# Generate two blank lists (to hold compare and intermediate results)
int_list <- list()
comp_list <- list()

# Generate loop list
doublecount <- (endblock - startblock) * 2
nlist <- floor(seq(startblock, doublecount + 1) /2)
simlist <- c("_sim", "_seq")
nlist <- paste0(simlist, nlist)
rm(simlist, doublecount)

# Initial comp model - OLS direct effects
indvars <- select_at(run_data, vars(contains("_s")))
comp_list$model1=lm(run_data$dep_var ~ ., data=indvars)
rm(indvars)

# Gen empty decor_data data frame for orthogonalized covariates
decor_data <- data.frame()

# Initiate block and covariate counter variable
b <- 1
k <- 1
save_count <- 1

# Ext. Laplace loop
for (i in nlist) {
  
  ## List covariates in block
  c_list <- colnames(select_at(run_data, vars(contains(i))))
  c_group <- data.frame(select_at(run_data, vars(contains(i))))
  
  # Set group counters
  g <- 1
  G <- ncol(c_group)
  
  # Covariate block loop
  for (grp in g:G) {
    
    # Set try catch flag
    skip_to_next <- FALSE
    
    # Run OLS - if valid, continue, if invalid, move to next covariate
    tryCatch( model <- lm(c_group[,grp] ~ ., data=decor_data), error = function(e) { skip_to_next <<- TRUE}) #change to decor_data
    if(skip_to_next) { next } #End if skip
    
    # Check R^2 and drop model if above threshold
    r2 <- summary(model)$r.squared
    
    if(r2 > collin_tolerance) { 
      
      # Drop covariate and move to next covariate
      c_group = subset(c_group, select=-c(grp))
      
      next 
      
    } #End if r2
    
    # Add model to results list and proceed
    # Indicate which group to begin saving results - e.g., save_start = 1 begins saving group 1, save_start = 2 begins saving group 2...
    save_start <- 3
    # Save loop
    if (k >= save_start) {
      
      # Save model
      int_list[[save_count]] <- model
      
      # Advance save counter
      save_count = save_count + 1
      
    } #End if save to results list
    
    # Predict
    yhat <- predict(model, newdata = decor_data) #change to decor_data
    
    # Replace in c_group
    c_group[[grp]] <- c_group[[grp]] - yhat 
    
    # If sequential - add replacement to decor_data 
    target <- "_seq"
    if(grepl(target, i, fixed = TRUE)) {
      
      # Retrieve current variable 
      s_element <- c_list[grp]
      # Append variable into data
      decor_data <- append(decor_data, select_at(c_group, vars(contains(s_element))))
      
    } #End if sequential
    
    # Advance covariate counter
    k <- k + 1
    
  } #End loop over block
  
  # If block is simultaneous - add to decor_data 
  target <- "_sim"
  if(grepl(target, i, fixed = TRUE)) {
    
    # Populate decor_data if first block, add to it if a later block 
    if (b == 1) {
      
      # Populate
      decor_data <- c_group
      
    } else {
      
      # Add block 
      decor_data <- cbind(decor_data, c_group)
      
    } #End counter else
    
  } #End if simultaneous
  
  # Advance block counter
  b <- b + 1
  
} #End Laplace loop

# Terminal comparison model - OLS direct vs Laplace total effects
model <- lm(run_data$dep_var ~ ., data=decor_data)
int_list[[save_count]] <- model
comp_list[[2]] <- model
