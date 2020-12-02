EXPERIMENT_SUPER <- normalizePath('..')
MODEL_SCRIPT_PATH <- normalizePath(ROOT_PATH, 'julia', 'main.jl')

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

escape_backslashes <- function(path) {
  str_replace_all(path, fixed('\\'), '\\\\')
}

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

# Plot things
source(file.path("{escape_backslashes(EXPERIMENT_SUPER)}", "plot_run.R"))
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
