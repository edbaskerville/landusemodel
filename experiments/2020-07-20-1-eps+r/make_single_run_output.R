#!/usr/bin/env Rscript

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

main <- function() {
  stopifnot(!file.exists('output.Rds'))
  
  # Read quantities generated over time within simulation
  output_table <- read.csv('output.csv')
  
  last_output_time <- max(output_table$time)
  
  config <- fromJSON('config.json')
  L <- config$L
  db_conn <- dbConnect(SQLite(), 'state_changes.sqlite')
  
  H <- matrix(as.numeric(NA), nrow = L, ncol = L)
  beta <- matrix(as.numeric(NA), nrow = L, ncol = L)
  
  # For each timestep, update H and beta from state changes and compute statistics
  H_beta_summary <- bind_rows(lapply(0:last_output_time, function(time) {
    last_time <- time - 1
    state_changes <- dbGetQuery(
      db_conn,
      str_glue('SELECT * FROM state_changes WHERE time > {last_time} AND time <= {time}')
    )
    for(i in 1:nrow(state_changes)) {
      row <- state_changes$row[i] + 1
      col <- state_changes$col[i] + 1
      H[row, col] <- state_changes$P[i]
      beta[row, col] <- state_changes$beta[i]
    }
    summarize_at_time(time, H, beta)
  }))
  
  saveRDS(
    output_table %>% left_join(H_beta_summary, by = 'time'),
    'output.Rds'
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
