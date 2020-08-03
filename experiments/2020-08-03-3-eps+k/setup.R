#!/usr/bin/env Rscript

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

N_JOBS <- 100
MAX_CORES_PER_JOB <- 14
HOURS_PER_RUN <- 6

N_REPLICATES <- 10

PARAM_VALS <- list(
  #productivityFunction = c('A', 'AF'),
  epsilon = seq(1, 10, 1),
  k = seq(0.0, 1.0, 0.1),
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

main <- function() {
  stopifnot(!dir.exists('runs'))
  stopifnot(!dir.exists('jobs'))
  stopifnot(!dir.exists('jobs_first'))
  stopifnot(!dir.exists('jobs_rest'))
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
  
  # Create a set of SLURM jobs for the first replicate of each parameter combo
  # for the sake of initial testing and debugging across parameter space
  n_jobs_first <- set_up_jobs(
   runs %>% filter(replicate_id == 1),
   'jobs_first', 1, 'submit_first.sh'
  )
  
  # Create another set of SLURM jobs for the remaining replicates
  if(N_REPLICATES > 1) {
   set_up_jobs(
     runs %>% filter(replicate_id > 1),
     'jobs_rest', n_jobs_first + 1, 'submit_rest.sh'
   )
  }

#   set_up_jobs(
#     runs, 'jobs', 1, 'submit.sh'
#   )
}


# Wrapper for srun wrapper script to handle failures

SRUN_WRAPPER_TEMPLATE = '#!/bin/bash

cd {run_dir}
./run.sh 2> stderr.txt 1> stdout.txt || cp -r "$SLURM_TMPDIR/{run_id}" ./tmp
'


# Template for script to perform a single run
RUN_SCRIPT_TEMPLATE = '#!/bin/bash

set -e
env

RUN_ID={run_id}
RUN_DIR={run_dir}
TMP_DIR="$SLURM_TMPDIR/$RUN_ID"

# Copy and cd to SLURM_TMPDIR if running on cluster
# Otherwise just cd to the run directory
echo $SLURM_TMPDIR
if [[ $SLURM_TMPDIR ]]; then
  mkdir "$TMP_DIR"
  cd "$TMP_DIR"
else
  cd "$RUN_DIR"
fi

# Actually run things
{RUN_EXEC_PATH} $RUN_DIR/config.json

# If on cluster, copy files back to main storage from SLURM_TMPDIR
if [[ "$SLURM_TMPDIR" ]]; then
  cd "$RUN_DIR"
  cp "$TMP_DIR"/parameters_out.json .
  cp "$TMP_DIR"/output.csv .
fi
'

set_up_run <- function(run_row) {
  print(run_row)
  
  run_id <- run_row$run_id
  run_dir <- file.path(normalizePath('runs'), str_glue('{run_id}'))
  dir.create(run_dir)
  
  # Assign parameters for config.json
  config <- BASE_CONFIG
  config$run_id = run_id
  for(param_name in names(PARAM_VALS)) {
    config[[param_name]] <- run_row[[param_name]]
  }
  
  # Write config.json
  write(
    toJSON(config, auto_unbox = TRUE, digits = NA, pretty = TRUE),
    file.path(run_dir, 'config.json')
  )
  
  # Write srun wrapper script
  srun_wrapper_path <- file.path(run_dir, 'srun_wrapper.sh')
  write(
    str_glue(SRUN_WRAPPER_TEMPLATE),
    srun_wrapper_path
  )
  system(str_glue('chmod +x {srun_wrapper_path}'))
  
  # Write run script
  run_script_path <- file.path(run_dir, 'run.sh')
  write(
    str_glue(RUN_SCRIPT_TEMPLATE),
    run_script_path
  )
  system(str_glue('chmod +x {run_script_path}'))
}

set_up_jobs <- function(runs, jobs_path, job_id_start, submit_filename) {
  print('set up jobs')
  
  dir.create(jobs_path)
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

# Template for job script
JOB_SCRIPT_TEMPLATE <- '#!/bin/bash

#SBATCH --job-name=LUM-{job_id}

#SBATCH --account=pi-pascualmm
#SBATCH --partition=broadwl

#SBATCH --time={time_hours}:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node={n_cores}
#SBATCH --mem-per-cpu=2000

#SBATCH --chdir={job_path}
#SBATCH --output=stdout.txt
#SBATCH --error=stderr.txt

module purge

module load parallel
module load java/11.0.1

parallel --delay 0.2 -j $SLURM_NTASKS --joblog runlog.txt --resume < runs.sh
'

write_job_script <- function(jobs_path, job_id, run_ids) {
  n_runs <- length(run_ids)
  runs_path <- normalizePath('runs')
  
  job_path <- file.path(jobs_path, str_glue('{job_id}'))
  dir.create(job_path)
  
  run_ids_str <- str_flatten(run_ids, collapse = ' ')
  
  write(
    str_flatten(sapply(run_ids, function(run_id) {
      str_glue('srun --exclusive -N1 -n1 {runs_path}/{run_id}/srun_wrapper.sh')
    }), collapse = '\n'),
    file.path(job_path, 'runs.sh')
  )
  
  job_script_path <- file.path(job_path, 'job.sbatch')
  n_cores <- min(n_runs, MAX_CORES_PER_JOB)
  time_hours <- HOURS_PER_RUN * ceiling(n_runs / n_cores)
  write(
    str_glue(JOB_SCRIPT_TEMPLATE),
    job_script_path
  )
  system(str_glue('chmod +x {job_script_path}'))
}

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
