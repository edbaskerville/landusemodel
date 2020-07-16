#!/usr/bin/env Rscript

library(jsonlite)
library(lhs)
library(dplyr)
library(tidyr)
library(stringr)

main <- function() {
  stopifnot(!file.exists('summary.Rds'))
  
  config <- fromJSON('config.json')
  state_changes <- read.csv('state_changes.csv')
  
  # Compute P, beta over time
  result <- construct_P_beta_over_time(config, state_changes)
  time <- result$time
  P <- result$P
  beta <- result$beta
  
  # Get summary statistics at each time point
  summary <- bind_rows(lapply(1:length(time), function(i) {
    summarize_at_time(time[i], P[,,i], beta[,,i])
  }))
  
  saveRDS(summary, 'summary.Rds')
}

construct_P_beta_over_time <- function(config, state_changes) {
  L <- config$L
  
  time <- 0:config$maxTime
  
  # Initialize L x L x (maxTime + 1) arrays to contain P, beta over time
  P <- array(as.numeric(NA), dim = c(L, L, length(time)))
  beta <- array(as.numeric(NA), dim = c(L, L, length(time)))
  
  # Initialize LxL matrices for current P, beta 
  # in which to accumulate state changes
  P_now <- matrix(as.numeric(NA), nrow = L, ncol = L)
  beta_now <- matrix(as.numeric(NA), nrow = L, ncol = L)
  
  # Process each state change sequentially
  time_next <- 0
  for(i in 1:nrow(state_changes)) {
    time_now <- state_changes$time[i]
    
    # If the state change is past one or more unrecorded timesteps,
    # we need to copy P_now, beta_now into those timesteps before absorbing
    # the new change
    while(time_now > time_next) {
      P[,,time_next + 1] <- P_now
      beta[,,time_next + 1] <- beta_now
      time_next <- time_next + 1
    }
    
    # Finally, modify P_now and beta_now according to the state change
    row <- state_changes$row[i] + 1
    col <- state_changes$col[i] + 1
    P_now[row, col] <- state_changes$P[i]
    beta_now[row, col] <- state_changes$beta[i]
  }
  
  # Record the last state
  P[,,length(time)] <- P_now
  beta[,,length(time)] <- beta_now
  
  list(
    time = time,
    P = P,
    beta = beta
  )
}

summarize_at_time <- function(time, P, beta) {
  beta_vec <- as.numeric(beta)
  
  # Simple stuff
  row <- data.frame(
    time = time,
    n_P = sum(P),
    beta_mean = mean(beta_vec, na.rm = TRUE),
    beta_sd = sd(beta_vec, na.rm = TRUE)
  )
  
  # Add lotsa quantiles
  for(q_str in c('025', '050', '100', '250', '500', '750', '900', '975')) {
    row[[str_glue('beta_{q_str}')]] <- quantile(beta_vec, as.numeric(q_str) / 1000, na.rm = TRUE)
  }
  
  row
}

main()
