#!/usr/bin/env Rscript

library(jsonlite)
library(lhs)
library(dplyr)
library(tidyr)
library(stringr)

OUTPUT_PATH <- 'output'

N_LHS_SAMPLES <- 10

LHS_PARAMS <- list(
  mu = c(0.1, 0.3),
  r = c(1.1, 1.9)
)

# Starting point for run config.json files
BASE_CONFIG <- list(
  spatial = TRUE,
  k = 0.0,
  maxTime = 1000.0,
  outputStateChanges = TRUE,
  outputImages = FALSE,
  outputFullState = FALSE,
  logInterval = 1.0,
  sigma = 0.2,
  c = 0.001,
  deltaF = TRUE,
  delta = 0.5,
  m = 0.2,
  q = 1,
  epsilon = 6,
  epsilonF = FALSE,
  beta0 = 1.0,
  r = 1.5,
  useDP = FALSE,
  productivityFunction = "AF",
  L = 200
)

ROOT_PATH <- normalizePath('..')
RUN_EXEC_PATH <- file.path(ROOT_PATH, 'run.sh')
SUMMARIZE_RUN_PATH <- normalizePath('../summarize_run.R')

# Template for job script
JOB_SCRIPT_TEMPLATE <- '#!/bin/bash

#SBATCH --job-name=LUM-{run_num}
#SBATCH --output=stdout.txt
#SBATCH --error=stderr.txt
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1

{RUN_EXEC_PATH} config.json
Rscript {SUMMARIZE_RUN_PATH} || exit 1
# rm state_changes.csv
'

main <- function() {
  stopifnot(!dir.exists(OUTPUT_PATH))
  dir.create(OUTPUT_PATH)
  
  # Create and save table containing parameter values for each run
  parameter_table <- make_parameter_table()
  write.csv(
    parameter_table, file.path(OUTPUT_PATH, 'parameters.csv'),
    row.names = FALSE
  )
  
  # Create a directory with config file for each run
  for(i in 1:N_LHS_SAMPLES) {
    set_up_run(i, parameter_table %>% filter(run == i))
  }
  
  # Create a script to sequentially submit each run to SLURM
  write_submit_script()
}

make_parameter_table <- function() {
  # Latin hypercube sample for parameters, in range (0, 1)
  lhs_samples <- randomLHS(N_LHS_SAMPLES, length(LHS_PARAMS))
  
  bind_rows(lapply(1:N_LHS_SAMPLES, function(i) {
    bind_rows(lapply(1:length(LHS_PARAMS), function(j) {
      make_parameter_row(i, j, lhs_samples[i,j])
    }))
  }))
}

make_parameter_row <- function(run_num, param_index, value_01) {
  param_name <- names(LHS_PARAMS)[param_index]
  param_range <- LHS_PARAMS[[param_index]]
  param_min <- param_range[1]
  param_max <- param_range[2]
  
  tibble(
    run = run_num,
    name = param_name,
    value = param_min + (param_max - param_min) * value_01
  )
}

set_up_run <- function(run_num, params) {
  run_path <- file.path(OUTPUT_PATH, sprintf('%d', run_num))
  dir.create(run_path)
  
  # Assign parameters for config.json
  config <- BASE_CONFIG
  for(i in 1:nrow(params)) {
    config[[params$name[i]]] <- params$value[i]
  }
  
  # Write config.json
  write(
    toJSON(config, auto_unbox = TRUE, digits = NA, pretty = TRUE),
    file.path(run_path, 'config.json')
  )
  
  # Write run script
  write(
    str_glue(JOB_SCRIPT_TEMPLATE),
    file.path(run_path, 'run.sbatch')
  )
}

write_submit_script <- function() {
  write(
    str_glue(
      '#!/bin/sh',
      str_flatten(
        sapply(1:N_LHS_SAMPLES, function(i) {
          run_path <- normalizePath(file.path(
            OUTPUT_PATH, str_glue('{i}'), 'run.sbatch'
          ))
          str_glue('sbatch {run_path}')
        }),
        collapse = '\n'
      ),
      .sep = '\n'
    ),
    'submit.sh'
  )
  
  # Make script executable
  system('chmod +x submit.sh')
}

main()
