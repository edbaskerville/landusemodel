#!/usr/bin/env Rscript

library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

main <- function() {
  # Get run numbers by listing the output directory
  run_ids <- sort(as.integer(list.dirs(
    'runs', full.names = FALSE, recursive = FALSE
  )))
  
  # Write output to database, one run at a time
  db_conn <- dbConnect(SQLite(), 'db.sqlite')
  dbCreateTable(db_conn, 'output', load_output(run_ids[1]))
  for(run_id in run_ids) {
    output <- load_output(run_id)
    if(!is.null(output)) {
      cat(sprintf('Collating run id %d\n', run_id))
      dbAppendTable(db_conn, 'output', output)
      gc()
    }
  }
  dbDisconnect(db_conn)
}

load_output <- function(run_id) {
  filename <- file.path(file.path(
    'runs', str_glue('{run_id}'), 'output.Rds'
  ))
  if(file.exists(filename)) {
    readRDS(filename) %>% mutate(
      run_id = run_id
    ) %>%
      select(run_id, everything())
  }
  else {
    NULL
  }
}

main()
