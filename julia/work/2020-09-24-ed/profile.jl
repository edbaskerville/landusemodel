#!/usr/bin/env julia

using Logging
using Random
using JSON2
using Profile
using Juno

include("../../model.jl")

params = load_parameters_from_json("parameters.json")
s = Simulation(params)

run(`../../remove_output.sh`)
Profile.clear()
@profile simulate(s)

Juno.profiler()
