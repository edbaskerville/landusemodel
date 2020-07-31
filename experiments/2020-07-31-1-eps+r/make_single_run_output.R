#!/usr/bin/env Rscript

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

main <- function() {
  stopifnot(!file.exists('output.sqlite'))
  
  # Read quantities generated over time within simulation
  output_table_raw <- read.csv('output.csv')
  
  last_output_time <- max(output_table_raw$time)
  
  config <- fromJSON('config.json')
  L <- config$L
  db_conn <- dbConnect(SQLite(), 'state_changes.sqlite')
  
  H <- matrix(as.numeric(NA), nrow = L, ncol = L)
  beta <- matrix(as.numeric(NA), nrow = L, ncol = L)
  
  H_beta_summary <- NULL
  
  # For each timestep, update H and beta from state changes and compute statistics
  for(time in 0:last_output_time) {
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
    
    summary_t <- summarize_at_time(time, H, beta)
    if(is.null(H_beta_summary)) {
      H_beta_summary <- summary_t
    }
    else {
      H_beta_summary <- bind_rows(H_beta_summary, summary_t)
    }
  }
  
  dbDisconnect(db_conn)
  
  output_table <- output_table_raw %>% left_join(H_beta_summary, by = 'time')
  output_table$run_id <- config$run_id
  db_conn_2 <- dbConnect(SQLite(), 'output.sqlite')
  dbWriteTable(db_conn_2, 'output', output_table)
  dbDisconnect(db_conn_2)
}

summarize_at_time <- function(time, H, beta) {
  beta_vec <- as.numeric(beta)
  cat(sprintf('t = %f, n_H = %d, n_beta = %f\n', time, sum(H, na.rm = TRUE), sum(!is.na(beta_vec))))
  
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
