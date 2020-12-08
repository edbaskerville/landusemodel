#!/usr/bin/env Rscript

ROOT_PATH <- normalizePath(file.path('..', '..', '..'))

N_JOBS <- 100
MAX_CORES_PER_JOB <- 14
MINUTES_PER_RUN <- 15

N_REPLICATES <- 1

PARAM_VALS <- list(
  replicate_id = 1:N_REPLICATES,
  
  # FH_A: conversion F->H depends on agriculture around humans
  # FH_AF: conversion F->H depends on forest around agriculture around humans
  productivity_function_FH = c('FH_A', 'FH_AF'),
  
  # Maximum rate of degradation of agriculture
  max_rate_AD = c(0.05, 0.1, 0.2, 0.5, 1.0, 2.0),
  
  # Fraction of max_rate_AD at maximum protection
  min_rate_frac_AD = seq(0.0, 1.0, 0.2),
  
  # Rate of forest recovery from degraded state.
  rate_DF = c(0.01, 0.02, 0.04, 0.10, 0.20),
  
  # Fixed beta
  beta_init_mean = c(0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0)
)

# Starting point for run config.json files
BASE_CONFIG <- list(
  L = 200,
  
  dt = 0.1,
  
  t_final = 1200,
  t_output = 1,
  
  init_H_frac = 0.01,
  
  max_rate_FH = 20,
  
  # Fraction of colonizations that come from anywhere on the lattice
  # (Need to explore a wider range of values)
  frac_global_FH = 0,
  
  # Fixed rate; all other rates relative to this one.
  # Maximum rate of abandonment of settlements: 1/(20 y)
  max_rate_HD = 0.05,
  
  # Minimum rate of abandonment of settlements
  min_rate_frac_HD = 0,
  
  # Constant beta
  sd_beta_init = 0.0,
  sd_beta = 0.0,
  
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

source('../setup_shared.R')
