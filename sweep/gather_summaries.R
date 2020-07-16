#!/usr/bin/env Rscript

library(dplyr)
library(tidyr)
library(stringr)

OUTPUT_PATH <- 'output'

main <- function() {
  # Get run numbers by listing the output directory
  run_nums <- sort(as.integer(list.dirs(
    OUTPUT_PATH, full.names = FALSE, recursive = FALSE
  )))
  
  # Gather up summary.Rds from each run that has it
  summary <- bind_rows(lapply(run_nums, function(run_num) {
    filename <- file.path(file.path(
      OUTPUT_PATH, str_glue('{run_num}'), 'summary.Rds'
    ))
    if(file.exists(filename)) {
      readRDS(filename) %>% mutate(
        run_num = run_num
      ) %>%
        select(run_num, everything())
    }
    else {
      NULL
    }
  }))
  
  saveRDS(summary, 'summary.Rds')
}

main()
