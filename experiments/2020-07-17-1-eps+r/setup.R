#!/usr/bin/env Rscript

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

N_REPLICATES <- 10

PARAM_VALS <- list(
  productivityFunction = c('A', 'AF'),
  epsilon = seq(0, 10, 1),
  r = seq(0.01, 0.1, 0.01),
  replicate_id = 1:N_REPLICATES
)

# Starting point for run config.json files
BASE_CONFIG <- list(
  epsilon = 3,
  q = 6,
  m = 0.01,
  c = 0.001,
  k = 0.0,
  
  spatial = TRUE,
  maxTime = 10000.0,
  outputStateChanges = TRUE,
  outputImages = FALSE,
  outputFullState = FALSE,
  logInterval = 1.0,
  sigma = 0.2,
  deltaF = TRUE,
  delta = 0.5,
  epsilonF = FALSE,
  beta0 = 1.0,
  useDP = FALSE,
  productivityFunction = "AF",
  L = 200
)

ROOT_PATH <- normalizePath(file.path('..', '..'))
RUN_EXEC_PATH <- file.path(ROOT_PATH, 'run.sh')
MAKE_OUTPUT_PATH <- normalizePath('make_single_run_output.R')

# Template for job script
JOB_SCRIPT_TEMPLATE <- '#!/bin/bash

#SBATCH --job-name=landusemodel-{run_id}

#SBATCH --account=pi-pascualmm
#SBATCH --partition=broadwl

#SBATCH --chdir={run_path}
#SBATCH --output=stdout.txt
#SBATCH --error=stderr.txt
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1

{RUN_EXEC_PATH} config.json
Rscript {MAKE_OUTPUT_PATH} || exit 1
rm state_changes.csv
'

main <- function() {
  stopifnot(!dir.exists('runs'))
  stopifnot(!file.exists('db.sqlite'))
  
  dir.create('runs')
  
  # Create table containing parameter values for each run
  runs <- {
    rt <- expand.grid(rev(PARAM_VALS), stringsAsFactors = FALSE)
    rt$run_id <- 1:nrow(rt)
    rt[,c('run_id', names(PARAM_VALS))]
  }
  
  # Write table to SQLite database
  db_conn <- dbConnect(SQLite(), 'db.sqlite')
  dbWriteTable(db_conn, 'runs', runs)
  dbDisconnect(db_conn)
  
  # Create a directory with config file for each run
  for(i in 1:nrow(runs)) {
    set_up_run(runs[i,])
  }
  
  # Create a script to sequentially submit each run to SLURM
  write_submit_script(runs %>% filter(replicate_id == 1), 'submit_first.sh')
  write_submit_script(runs %>% filter(replicate_id > 1), 'submit_rest.sh')
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

set_up_run <- function(run_row) {
  print(run_row)
  
  run_id <- run_row$run_id
  run_path <- file.path(normalizePath('runs'), str_glue('{run_id}'))
  dir.create(run_path)
  
  # Assign parameters for config.json
  config <- BASE_CONFIG
  for(param_name in names(PARAM_VALS)) {
    config[[param_name]] <- run_row[[param_name]]
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

write_submit_script <- function(runs, filename) {
  write(
    str_glue(
      '#!/bin/sh',
      str_flatten(
        sapply(runs$run_id, function(run_id) {
	  run_path <- normalizePath(file.path('runs', str_glue('{run_id}')))
          sbatch_path <- file.path(run_path, 'run.sbatch')
          str_glue('sbatch {sbatch_path}')
        }),
        collapse = '\n'
      ),
      .sep = '\n'
    ),
    filename
  )
  
  # Make script executable
  system(str_glue('chmod +x {filename}'))
}

main()
warnings()
