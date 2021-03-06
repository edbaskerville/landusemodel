#!/usr/bin/env Rscript

ROOT_PATH <- normalizePath(file.path('..', '..', '..'))

N_JOBS <- 1
MAX_CORES_PER_JOB <- 16
MINUTES_PER_RUN <- 15

N_REPLICATES <- 1

PARAM_VALS <- list(
  replicate_id = 1:N_REPLICATES,
  
  # FH_A: conversion F->H depends on agriculture around humans
  # FH_AF: conversion F->H depends on forest around agriculture around humans
  productivity_function_FH = c('FH_A', 'FH_AF'),
  
  # Maximum colonization rate of a patch of forest
  max_rate_FH = seq(12, 40, 4),
  
  # Rate of forest recovery from degraded state.
  rate_DF = c(0.05, 0.10, 0.15, 0.20)
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
  beta_init_mean = 0.5,
  sd_beta_init = 0.5,
  sd_beta = 1.0,
  
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
