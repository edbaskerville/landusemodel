#!/usr/bin/env Rscript

library(RSQLite)
library(stringr)

escape_backslashes <- function(path) {
  str_replace_all(path, fixed('\\'), '\\\\')
}

main <- function() {
  stopifnot(file.exists('db.sqlite'))
  
  db <- dbConnect(SQLite(), 'db.sqlite')
  
  dbExecute(db, 'BEGIN TRANSACTION')
  dbExecute(db, '
    CREATE TABLE output (
    run_id INTEGER,
    time REAL,
    H INTEGER, H_lifetime_avg REAL,
    A INTEGER, A_lifetime_avg REAL,
    F INTEGER, F_lifetime_avg REAL,
    D INTEGER, D_lifetime_avg REAL,
    beta_mean REAL, beta_sd REAL,
    beta_min REAL, beta_max REAL,
    beta_025 REAL, beta_050 REAL, beta_100 REAL, beta_250 REAL, beta_500 REAL, beta_750 REAL, beta_900 REAL, beta_950 REAL, beta_975 REAL
    );
  ')
  dbExecute(db, 'COMMIT')
  
  for(run_id in sort(run_ids())) {
    cat(sprintf('Processing %s...\n', run_id))
    
    run_db_path <- db_path(run_id)
    dbExecute(db, str_glue('ATTACH DATABASE "{escape_backslashes(run_db_path)}" AS src'))
    dbExecute(db, 'BEGIN TRANSACTION')
    
    dbExecute(db, str_glue('INSERT INTO output SELECT {run_id}, * FROM src.output'))
    
    dbExecute(db, 'COMMIT')
    dbExecute(db, 'DETACH DATABASE src')
  }
  
  dbExecute(db, 'BEGIN TRANSACTION')
  dbExecute(db, 'CREATE INDEX output_index ON output (run_id);')
  dbExecute(db, 'COMMIT')
  
  dbDisconnect(db)
}

db_path <- function(run_id) {
  file.path('runs', str_glue('{run_id}'), 'output.sqlite')
}

run_ids <- function() {
  run_ids_vec <- numeric(0)
  for(run_id_str in list.dirs('runs', full.names=FALSE, recursive=FALSE)) {
    run_id <- as.integer(run_id_str)
    if(!is.na(run_id)) {
      if(file.exists(db_path(run_id))) {
        run_ids_vec <- c(run_ids_vec, run_id)
      }
    }
  }
  run_ids_vec
}

main()
