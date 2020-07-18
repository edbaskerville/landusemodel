#!/usr/bin/env Rscript

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)

main <- function() {
  stopifnot(!file.exists('output.Rds'))
  
  # Read quantities generated over time within simulation
  output_table <- read.csv('output.csv')
  
  config <- fromJSON('config.json')
  state_changes <- read.csv('state_changes.csv')
  
  # Compute H, beta over time
  result <- construct_H_beta_over_time(config, state_changes, max(output_table$time))
  time <- result$time
  H <- result$H
  beta <- result$beta
  
  # Get summary statistics at each time point
  H_beta_summary <- bind_rows(lapply(1:length(time), function(i) {
    summarize_at_time(time[i], H[,,i], beta[,,i])
  }))
  
  saveRDS(
    output_table %>% left_join(H_beta_summary, by = 'time'),
    'output.Rds'
  )
}

construct_H_beta_over_time <- function(config, state_changes, last_output_time) {
  L <- config$L
  
  time <- 0:last_output_time
  
  # Initialize L x L x (maxTime + 1) arrays to contain H, beta over time
  H <- array(as.numeric(NA), dim = c(L, L, length(time)))
  beta <- array(as.numeric(NA), dim = c(L, L, length(time)))
  
  # Initialize LxL matrices for current H, beta 
  # in which to accumulate state changes
  H_now <- matrix(as.numeric(NA), nrow = L, ncol = L)
  beta_now <- matrix(as.numeric(NA), nrow = L, ncol = L)
  
  # Process each state change sequentially
  time_next <- 0
  for(i in 1:nrow(state_changes)) {
    time_now <- state_changes$time[i]
    
    # If the state change is past one or more unrecorded timesteps,
    # we need to copy H_now, beta_now into those timesteps before absorbing
    # the new change
    while(time_now > time_next) {
      H[,,time_next + 1] <- H_now
      beta[,,time_next + 1] <- beta_now
      time_next <- time_next + 1
    }
    
    # Finally, modify H_now and beta_now according to the state change
    row <- state_changes$row[i] + 1
    col <- state_changes$col[i] + 1
    H_now[row, col] <- state_changes$P[i]
    beta_now[row, col] <- state_changes$beta[i]
  }
  
  # Record the last state
  H[,,length(time)] <- H_now
  beta[,,length(time)] <- beta_now
  
  list(
    time = time,
    H = H,
    beta = beta
  )
}

summarize_at_time <- function(time, H, beta) {
  beta_vec <- as.numeric(beta)
  
  # Simple stuff
  row <- data.frame(
    time = time,
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
