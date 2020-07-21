#!/usr/bin/env Rscript

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

N_JOBS <- 500

N_REPLICATES <- 10

PARAM_VALS <- list(
  productivityFunction = c('A', 'AF'),
  epsilon = seq(0, 10, 1),
  r = seq(0.05, 0.5, 0.05),
  replicate_id = 1:N_REPLICATES
)

# Starting point for run config.json files
BASE_CONFIG <- list(
  epsilon = 3,
  q = 6,
  m = 0.01,
  c = 0.001,
  k = 0.0,
  productivityFunction = 'AF',
  
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
  L = 200
)

ROOT_PATH <- normalizePath(file.path('..', '..'))
RUN_EXEC_PATH <- file.path(ROOT_PATH, 'run.sh')
MAKE_OUTPUT_PATH <- normalizePath('make_single_run_output.R')

# Template for script to perform a single run
RUN_SCRIPT_TEMPLATE = '#!/bin/bash
{RUN_EXEC_PATH} config.json
Rscript {MAKE_OUTPUT_PATH} || exit 1
rm state_changes.csv
'

# Template for job script
JOB_SCRIPT_TEMPLATE <- '#!/bin/bash

#SBATCH --job-name=LUM-{job_id}

#SBATCH --account=pi-pascualmm
#SBATCH --partition=broadwl

#SBATCH --time={n_runs}:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem-per-cpu=2000

#SBATCH --chdir={job_path}
#SBATCH --output=stdout.txt
#SBATCH --error=stderr.txt

for i in {{{run_id_start}..{run_id_end}}}
do
  echo "Run $i"
  cd {runs_path}/$i
  bash run.sh
done
'

main <- function() {
  stopifnot(!dir.exists('runs'))
  stopifnot(!dir.exists('jobs'))
  stopifnot(!file.exists('db.sqlite'))
  
  dir.create('runs')
  dir.create('jobs')
  
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
  
  # Split up the runs among a maximum of N_JOBS jobs
  n_jobs <- min(nrow(runs), N_JOBS)
  n_runs_by_job <- distribute_evenly(nrow(runs), n_jobs)
  run_id_start <- c(0, cumsum(n_runs_by_job))[1:n_jobs] + 1
  run_id_end <- cumsum(n_runs_by_job)
  for(i in 1:n_jobs) {
    write_job_script(i, run_id_start[i], run_id_end[i])
  }
  
  # Create a script to submit all the jobs to SLURM
  write_submit_script(n_jobs, 'submit.sh')
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
  run_script_path <- file.path(run_path, 'run.sh')
  write(
    str_glue(RUN_SCRIPT_TEMPLATE),
    file.path(run_path, 'run.sh')
  )
  system(str_glue('chmod +x {run_script_path}'))
}

write_job_script <- function(job_id, run_id_start, run_id_end) {
  jobs_path <- normalizePath('jobs')
  runs_path <- normalizePath('runs')
  job_path <- file.path(jobs_path, str_glue('{job_id}'))
  dir.create(job_path)
  
  n_runs <- run_id_end - run_id_start + 1
  job_script_path <- file.path(job_path, 'job.sbatch')
  write(
    str_glue(JOB_SCRIPT_TEMPLATE),
    job_script_path
  )
  system(str_glue('chmod +x {job_script_path}'))
}

write_submit_script <- function(n_jobs, filename) {
  write(
    str_glue(
      '#!/bin/sh',
      str_flatten(
        sapply(1:n_jobs, function(job_id) {
          job_path <- normalizePath(file.path('jobs', str_glue('{job_id}')))
          sbatch_path <- file.path(job_path, 'job.sbatch')
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

distribute_evenly <- function(n, k) {
  a <- rep(n %/% k, k)
  r <- n %% k
  if(r > 0) {
    a[1:r] <- a[1:r] + 1
  }
  stopifnot(all(a >= (n %/% k)))
  stopifnot(sum(a) == n)
  a
}

main()
warnings()
