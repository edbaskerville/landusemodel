#!/usr/bin/env julia

using Logging
using Random
using JSON2

include("model.jl")

# Uncomment this to see all debugging output (makes things very slow):
# Logging.global_logger(
#     Logging.SimpleLogger(
#         stderr,
#         Logging.Debug
#     )
# )

function main()
    params = load_parameters_from_json(ARGS[1])
    s = Simulation(params)
    
    simulate(s)
end

main()
