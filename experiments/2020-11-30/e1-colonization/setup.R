#!/usr/bin/env Rscript

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

escape_backslashes <- function(path) {
  str_replace_all(path, fixed('\\'), '\\\\')
}

MODEL_SCRIPT_PATH <- normalizePath(file.path('..', '..', '..', 'julia', 'main.jl'))
N_JOBS <- 1
MAX_CORES_PER_JOB <- 2
MINUTES_PER_RUN <- 15

N_REPLICATES <- 1

PARAM_VALS <- list(
  replicate_id = 1:N_REPLICATES,
  
  # FH_A: conversion F->H depends on agriculture around humans
  # FH_AF: conversion F->H depends on forest around agriculture around humans
  productivity_function_FH = c('FH_A', 'FH_AF'),
  
  # Maximum colonization rate of a patch of forest
  # 5 to 40 by 5 (8 values)
  max_rate_FH = seq(5, 40, 5),
  
  # Rate of forest recovery from degraded state.
  # Corresponds to mean forest recovery time in years: 100, 50, 25, 10
  # Ratio (forest time) / (human abandonment time) = 5, 2.5, 1.25, 0.5
  rate_DF = c(0.01, 0.02, 0.04, 0.1)
)

# Starting point for run config.json files
BASE_CONFIG <- list(
  L = 200,
  
  dt = 0.1,
  
  t_final = 300,
  t_output = 1,
  
  # Fraction of colonizations that come from anywhere on the lattice
  # (Need to explore a wider range of values)
  frac_global_FH = 0,
  
  # Rate of degradation of agriculture.
  max_rate_AD = 1/5,
  
  # Maximum forest levels results in no degradation
  min_rate_frac_AD = 0,
  
  # Fixed rate; all other rates relative to this one.
  # Maximum rate of abandonment of settlements: 1/(20 y)
  max_rate_HD = 0.05,
  
  # Minimum rate of abandonment of settlements: 1/(20000 y)
  # Check: can this just be zero? (Yes.)
  min_rate_frac_HD = 0.001,
  
  # Beta initial value, standard deviation, random walk.
  # Maybe more initial variance would be good?
  # sd_log_beta = 0.1 means a about a 10% change per year.
  beta_init_mean = 0.4,
  sd_log_beta_init = 0.001,
  sd_log_beta = 0.1,
  
  enable_animation = FALSE,
  t_animation_frame = 1,
  
  H_color = c(0.0, 0.6, 0.9),
  A_color = c(1.0, 0.9, 0.1),
  F_color = c(0.1, 0.6, 0.1),
  D_color = c(0.6, 0.5, 0.2),
  
  beta_bg_color = c(0.9, 0.9, 0.9),
  beta_min_color = c(0.5, 0.1, 0.1),
  beta_max_color = c(0.99, 0.1, 0.1),
  beta_image_max = 0.2
)

main <- function() {
  stopifnot(!dir.exists('runs'))
  stopifnot(!dir.exists('jobs'))
  stopifnot(!file.exists('db.sqlite'))
  
  dir.create('runs')
  
  # Create table containing parameter values for each run
  runs <- {
    rt <- expand.grid(rev(PARAM_VALS), stringsAsFactors = FALSE)
    rt$rng_seed <- sample.int(2^31 - 1, nrow(rt))
    rt$run_id <- 1:nrow(rt)
    rt[,c('run_id', 'rng_seed', names(PARAM_VALS))]
  }
  
  # Write table to SQLite database
  db_conn <- dbConnect(SQLite(), 'db.sqlite')
  dbWriteTable(db_conn, 'runs', runs)
  dbDisconnect(db_conn)
  
  # Create a directory with config file for each run
  for(i in 1:nrow(runs)) {
    set_up_run(runs[i,])
  }
  
  # Create a set of SLURM jobs for the first replicate of each parameter combo
  # for the sake of initial testing and debugging across parameter space
  dir.create('jobs')
  n_jobs_first <- set_up_jobs(
   runs %>% filter(replicate_id == 1),
   'jobs', 1, 'submit_first.sh'
  )
  
  # Create another set of SLURM jobs for the remaining replicates
  if(N_REPLICATES > 1) {
   set_up_jobs(
     runs %>% filter(replicate_id > 1),
     'jobs', n_jobs_first + 1, 'submit_rest.sh'
   )
  }
}


# Template for script to perform a single run
RUN_SCRIPT_TEMPLATE = 'RUN_ID <- {run_id}
RUN_DIR <- "{escape_backslashes(run_dir)}"
setwd(RUN_DIR)

# Actually run things
system2(
  "julia",
  c("-p", "1", "--", "{escape_backslashes(MODEL_SCRIPT_PATH)}", file.path(RUN_DIR, "config.json")),
  stdout = "stdout.txt",
  stderr = "stderr.txt"
)
'

set_up_run <- function(run_row) {
  print(run_row)
  
  run_id <- run_row$run_id
  run_dir <- file.path(normalizePath('runs'), str_glue('{run_id}'))
  dir.create(run_dir)
  
  # Assign parameters for config.json
  config <- BASE_CONFIG
  for(param_name in colnames(run_row)) {
    config[[param_name]] <- run_row[[param_name]]
  }
  
  # Write config.json
  write(
    toJSON(config, auto_unbox = TRUE, digits = NA, pretty = TRUE),
    file.path(run_dir, 'config.json')
  )
  
  # Write run script
  run_script_path <- file.path(run_dir, 'run.R')
  write(
    str_glue(RUN_SCRIPT_TEMPLATE),
    run_script_path
  )
}

set_up_jobs <- function(runs, jobs_path, job_id_start, submit_filename) {
  print('set up jobs')
  
  jobs_path <- normalizePath(jobs_path)
  
  # Split up the runs among a maximum of N_JOBS jobs
  n_jobs <- min(nrow(runs), N_JOBS)
  n_runs_by_job <- distribute_evenly(nrow(runs), n_jobs)
  
  run_start <- c(0, cumsum(n_runs_by_job))[1:n_jobs] + 1
  run_end <- cumsum(n_runs_by_job)
  
  for(i in 1:n_jobs) {
    job_id <- job_id_start + i - 1
    cat(sprintf('job %d\n', job_id))
    write_job_script(jobs_path, job_id, runs$run_id[run_start[i]:run_end[i]])
  }
  
  write_submit_script(
    jobs_path, job_id_start, job_id_start + n_jobs - 1,
    submit_filename
  )
  
  n_jobs
}

# Template for job sbatch file
JOB_SBATCH_TEMPLATE <- '#!/bin/bash

#SBATCH --job-name=LUM-{job_id}

#SBATCH --account=pi-pascualmm
#SBATCH --partition=broadwl

#SBATCH --time={time_minutes}:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task={n_cores}
#SBATCH --mem-per-cpu=2000

#SBATCH --chdir={job_path}
#SBATCH --output=stdout.txt
#SBATCH --error=stderr.txt

module purge

module load R
module load julia

Rscript "{escape_backslashes(run_job_path)}"
'

# Template for job script file
JOB_SCRIPT_TEMPLATE <- '
RUNS_PATH <- "{escape_backslashes(runs_path)}"
RUN_IDS <- c({run_ids_str})

library(doParallel)
library(foreach)

cl <- makeCluster({n_cores})
registerDoParallel(cl)

foreach(run_id = RUN_IDS) %dopar% {{
  system2(
    "Rscript",
    file.path(RUNS_PATH, run_id, "run.R")
  )
}}

stopCluster(cl)
'


write_job_script <- function(jobs_path, job_id, run_ids) {
  n_runs <- length(run_ids)
  runs_path <- normalizePath('runs')
  n_cores <- min(n_runs, MAX_CORES_PER_JOB)
  time_minutes <- MINUTES_PER_RUN * ceiling(n_runs / n_cores)
  
  job_path <- file.path(jobs_path, str_glue('{job_id}'))
  dir.create(job_path)
  
  # Write R script for local or cluster execution
  run_job_path <- file.path(job_path, 'run_job.R')
  run_ids_str <- str_flatten(run_ids, collapse = ', ')
  write(
    str_glue(JOB_SCRIPT_TEMPLATE),
    run_job_path
  )
  
  # Write sbatch file for execution on SLURM
  write(
    str_glue(JOB_SBATCH_TEMPLATE),
    file.path(job_path, 'job.sbatch')
  )
}

# write_job_script <- function(jobs_path, job_id, run_ids) {
#   n_runs <- length(run_ids)
#   runs_path <- normalizePath('runs')
#   
#   job_path <- file.path(jobs_path, str_glue('{job_id}'))
#   dir.create(job_path)
#   
#   run_ids_str <- str_flatten(run_ids, collapse = ' ')
#   
#   write(
#     str_flatten(sapply(run_ids, function(run_id) {
#       prefix <- if(LOCAL) '' else 'srun --exclusive -N1 -n1 '
#       str_glue('{prefix}{runs_path}/{run_id}/run.R')
#     }), collapse = '\n'),
#     file.path(job_path, 'runs.sh')
#   )
#   
#   job_script_path <- file.path(job_path, 'job.sbatch')
#   n_cores <- min(n_runs, MAX_CORES_PER_JOB)
#   time_minutes <- MINUTES_PER_RUN * ceiling(n_runs / n_cores)
#   write(
#     str_glue(JOB_SCRIPT_TEMPLATE),
#     job_script_path
#   )
#   system(str_glue('chmod +x {job_script_path}'))
# }

# Template for submit script
SUBMIT_SCRIPT_TEMPLATE <- '#!/bin/bash
for job_id in {{{job_id_start}..{job_id_end}}}
do
  sbatch {jobs_path}/$job_id/job.sbatch
done
'

write_submit_script <- function(jobs_path, job_id_start, job_id_end, filename) {
  print('write_submit_script')
  
  write(
    str_glue(SUBMIT_SCRIPT_TEMPLATE),
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
