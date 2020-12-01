import Base.length
using Random
using Statistics
using StatsBase
using DataStructures: SortedDict
using Images
using FileIO
using Printf
using SQLite
using JSON2

include("util.jl")

### PARAMETERS

@enum FHProductivityFunction begin
    FH_A
    FH_AF
end

mutable struct Parameters
    rng_seed::Union{Int64, Nothing}

    L::Int64
    
    dt::Float64
    
    t_final::Float64
    t_output::Float64

    max_rate_FH::Float64
    frac_global_FH::Float64

    max_rate_AD::Float64
    min_rate_frac_AD::Float64

    max_rate_HD::Float64
    min_rate_frac_HD::Float64
    
    rate_DF::Float64
    
    beta_init_mean::Float64
    sd_beta_init::Union{Float64, Nothing}
    sd_log_beta_init::Union{Float64, Nothing}
    sd_log_beta::Union{Float64, Nothing}
    sd_beta::Union{Float64, Nothing}

    productivity_function_FH::FHProductivityFunction

    enable_animation::Bool
    t_animation_frame::Float64

    H_color::Vector{Float64}
    A_color::Vector{Float64}
    F_color::Vector{Float64}
    D_color::Vector{Float64}

    beta_bg_color::Vector{Float64}
    beta_min_color::Vector{Float64}
    beta_max_color::Vector{Float64}

    beta_image_max::Float64

    function Parameters()
        p = new()
        p.rng_seed = nothing
        p
    end
end
JSON2.@format Parameters noargs

function load_parameters_from_json(filename) :: Parameters
    str = open(f -> read(f, String), filename)
    params = JSON2.read(str, Parameters)
    params
end


### CONSTANTS

# Site states
STATES = Vector(1:4)
const H, A, F, D = STATES

### SIMULATION STATE AND INITIALIZATION

Loc = Tuple{Int64, Int64}

struct ModelState
    state::Matrix{Int64}
    tick_init::Matrix{Int64}
    beta::Matrix{Float64}
end

function ModelState(rng, p)
    L = p.L

    state = rand(rng, STATES, (L, L))
    tick_init = fill(Int64(0), (L, L))

    is_H = state .== H
    
    @assert (p.sd_beta_init === nothing) != (p.sd_log_beta_init === nothing)
    @assert (p.sd_beta === nothing) != (p.sd_log_beta === nothing)
    
    beta = if p.sd_beta_init === nothing
        p.beta_init_mean * is_H .* exp.(p.sd_log_beta_init * randn(rng, (L, L)))
    else
        max.(0.0, (p.beta_init_mean .+ p.sd_beta_init * randn(rng, (L, L))) .* is_H)
    end

    ModelState(state, tick_init, beta)
end

mutable struct Simulation
    params::Parameters
    rng::MersenneTwister

    model_state::ModelState
    
    lifetime_counts::Array{Int64}
    lifetime_sums::Array{Float64}

    function Simulation(params::Parameters)
        s = new()

        s.params = deepcopy(params)
        if s.params.rng_seed === nothing
            s.params.rng_seed = Int64(rand(RandomDevice(), UInt32))
        end
        p = s.params

        s.rng = MersenneTwister(s.params.rng_seed)
        s.model_state = ModelState(s.rng, p)
        s.lifetime_counts = zeros(Int64, size(STATES))
        s.lifetime_sums = zeros(Float64, size(STATES))

        s
    end
end


### SIMULATION LOOP

function simulate(s::Simulation)
    p = s.params
    db = init_output(p)

    # Repeatedly do events
    @assert p.dt <= 1.0
    steps_per_t = Int64(round(1.0 / p.dt))
    
    n_ticks = Int64(round(p.t_final * steps_per_t))
    ticks_per_output = Int64(round(p.t_output / p.dt))
    ticks_per_frame = Int64(round(p.t_animation_frame / p.dt))

    write_output(s, db, 0)
    if p.enable_animation
        write_animation_frame(s, 0)
    end

    for tick = 1:n_ticks
        step_simulation(s, tick)

        if tick % ticks_per_output == 0
            write_output(s, db, tick)
        end

        if p.enable_animation && (tick % ticks_per_frame == 0)
            write_animation_frame(s, tick ÷ ticks_per_frame)
        end
    end
end

const NEIGHBOR_OFFSETS = [
    (-1, -1), (-1,  0), (-1,  1),
    ( 0, -1),           ( 0,  1),
    ( 1, -1), ( 1,  0), ( 1,  1)
]

function map_neighbors(X)
    # Preallocate array
    Y = Array{valtype(X), 3}(undef, Tuple(vcat(collect(size(X)), [8])))

    # Compute circular shift at each offset
    for (i, offset) in enumerate(NEIGHBOR_OFFSETS)
        Y[:,:,i] = circshift(X, offset)
    end

    Y
end

function get_neighbors(X, ind)
    L = size(X)[1]
    map(offset -> X[CartesianIndex(apply_offset(ind, offset, L))], NEIGHBOR_OFFSETS)
end

function sum_over_neighbors(X)
    reshape(sum(map_neighbors(X), dims = 3), size(X))
end

# function draw_transitions(rate, dt)
#     prob = 1.0 .- exp.(-rate * dt)
#     rand(rng, Float64, size(prob)) .< prob
# end

function step_simulation(s::Simulation, tick::Int64)
#     println(tick)

    p = s.params
    rng = s.rng
    dt = p.dt

    LxL = (p.L, p.L)
    Hs = fill(H, LxL)
    As = fill(A, LxL)
    Fs = fill(F, LxL)
    Ds = fill(D, LxL)

    ms = s.model_state

    # Whether each site is in each state
    is_H = ms.state .== H
    is_A = ms.state .== A
    is_F = ms.state .== F
    is_D = ms.state .== D

    # println(findall(1 .- (is_H + is_A + is_F + is_D)))

    # @assert all(Matrix{Bool}(is_H + is_A + is_F + is_D))

    # Number of neighbors in each state
    nn_H = sum_over_neighbors(is_H)
    nn_A = sum_over_neighbors(is_A)
    nn_F = sum_over_neighbors(is_F)
    nn_D = sum_over_neighbors(is_D)

    # Precompute random matrices for drawing transitions
    u_event = rand(rng, Float64, LxL)
    u_state = rand(rng, Float64, LxL)

    function draw_event_happened(rate)
        prob = 1.0 .- exp.(-rate * dt)
        u_event .< prob
    end

    # Perform a step starting from state H for each site
    function step_H()
        rate = p.max_rate_HD * (p.min_rate_frac_HD .+ (1.0 - p.min_rate_frac_HD) * (1.0 .- nn_A ./ 8.0))
        is_H .* draw_event_happened(rate)
    end

    # Perform a step starting from state A for each site
    function step_A()
        rate = p.max_rate_AD * (p.min_rate_frac_AD .+ (1.0 - p.min_rate_frac_AD) * (1.0 .- nn_F ./ 8.0))
        is_A .& draw_event_happened(rate)
    end

    function productivity_FH_A()
        # Density of A for locations in state H (assumes one neighbor is F)
        # (zeros for locations not in state H)
        density_A_H = is_H .* (sum_over_neighbors(is_A) ./ 7.0)

        # Mean density_A_H over neighbors for sites in state F
        mean_density_A_H = is_F .* (sum_over_neighbors(density_A_H) ./ 8.0)

        # Mean density_A_H over all sites (except the one in question)
        mean_density_A_H_global = sum(density_A_H) / (p.L * p.L - 1) * is_F
        
        (
            (1.0 - p.frac_global_FH) * mean_density_A_H,
            p.frac_global_FH * mean_density_A_H_global
        )
    end

    function productivity_FH_AF()
        # Density of F for locations in state A (assumes one neighbor is H)
        density_F_A = is_A .* (sum_over_neighbors(is_F) ./ 7.0)

        # Mean density_F_A over neighbors for sites in state H (assumes one neighbor is F)
        density_F_A_H = is_H .* (sum_over_neighbors(density_F_A) ./ 7.0)

        # Mean density_F_A_H over neighbors for sites in state F
        mean_density_F_A_H = is_F .* (sum_over_neighbors(density_F_A_H) ./ 8.0)

        # Mean density_F_A_H over all sites (except the one in question)
        mean_density_F_A_H_global = sum(density_F_A_H) / (p.L * p.L - 1) * is_F
        
        (
            (1.0 - p.frac_global_FH) * mean_density_F_A_H,
            p.frac_global_FH * mean_density_F_A_H_global
        )
    end

    function step_F()
        prod_local, prod_global = if p.productivity_function_FH == FH_A
            productivity_FH_A()
        else
            productivity_FH_AF()
        end
        prod_total = prod_local + prod_global
        rate_FH = p.max_rate_FH * prod_total
        
        rate_FA = sum_over_neighbors(ms.beta) ./ 8.0

        total_rate = rate_FH + rate_FA
        event_happened = is_F .& draw_event_happened(total_rate)
        next_state_is_H = event_happened .& (u_state .< rate_FH ./ total_rate )
        next_state_is_A = event_happened .& (1 .- next_state_is_H)
        new_state = next_state_is_H .* Hs + next_state_is_A .* As
        
        new_beta = zeros(Float64, LxL)
        all_betas = ms.beta[is_H]
        for ind in findall(next_state_is_H)
            if rand(rng) < prod_local[ind] / prod_total[ind]
                # If it was a local colonization event, copy beta from neighbor
                H_neighbor_indices = findall(get_neighbors(is_H, ind))
                neighbor_betas = get_neighbors(ms.beta, ind)[H_neighbor_indices]
                new_beta[ind] = rand(rng, neighbor_betas)
            else
                # Otherwise, copy random beta from anywhere on the lattice
                new_beta[ind] = rand(rng, all_betas)    
            end
        end

        (event_happened, new_state, new_beta)
    end

    function step_D()
        is_D .& draw_event_happened(fill(p.rate_DF, LxL))
    end

    # Compute the new state by doing a simple mask-and-add
    # from forward steps for each individual state

    changed_H = step_H()
    changed_A = step_A()
    changed_F, new_state_F, new_beta_FH = step_F()
    changed_D = step_D()
    
    changed_by_state = [changed_H, changed_A, changed_F, changed_D]

    changed = changed_H .| changed_A .| changed_F .| changed_D
    unchanged = 1 .- changed
    @assert all((unchanged .== 0) .| (unchanged .== 1))

    new_state = unchanged .* ms.state +
        changed_H .* Ds +
        changed_A .* Ds +
        new_state_F +
        changed_D .* Fs

    new_beta_before_walk = ms.beta .* (1.0 .- changed_H) + new_beta_FH
    new_beta = if p.sd_beta === nothing
        sd_dt = sqrt(p.sd_log_beta^2 * dt)
        exp.(sd_dt * randn(rng, LxL)) .* new_beta_before_walk
    else
        max.(
            0.0,
            (new_state .== H) .* (
                new_beta_before_walk .+ p.sd_beta * randn(rng, LxL)
            )
        )
    end
    
    for state in STATES
        s.lifetime_counts[state] += sum(changed_by_state[state])
        s.lifetime_sums[state] += sum(tick .- ms.tick_init[changed_by_state[state]]) * dt
    end
    new_tick_init = unchanged .* ms.tick_init + changed .* tick
    
    s.model_state = ModelState(new_state, new_tick_init, new_beta)
end

function init_output(p)
    if p.enable_animation
        if isdir("state_images")
            error("state_images already exists; delete first")
        end
        if isdir("beta_images")
            error("beta_images already exists; delete first")
        end
        mkdir("state_images")
        mkdir("beta_images")
    end

    if isfile("output.sqlite")
        error("output.sqlite already exists; delete first")
    end
    db = SQLite.DB("output.sqlite")

    DBInterface.execute(db, """
        CREATE TABLE output (
            time REAL,
            H INTEGER,
            H_lifetime_avg REAL,
            A INTEGER,
            A_lifetime_avg REAL,
            F INTEGER,
            F_lifetime_avg REAL,
            D INTEGER,
            D_lifetime_avg REAL,
            beta_mean REAL,
            beta_sd REAL,
            beta_min REAL,
            beta_max REAL,
            beta_025 REAL,
            beta_050 REAL,
            beta_100 REAL,
            beta_250 REAL,
            beta_500 REAL,
            beta_750 REAL,
            beta_900 REAL,
            beta_950 REAL,
            beta_975 REAL
        )
    """)
    db
end

function write_output(s::Simulation, db::SQLite.DB, tick::Int64)
    p = s.params
    ms = s.model_state
    t_output = tick * p.dt

    println("Outputting at ", t_output)

    betas = ms.beta[findall(ms.state .== H)]
    beta_mean = mean(betas)
    beta_sd = std(betas, corrected = false)
    beta_min = if length(betas) == 0
        NaN
    else
        minimum(betas)
    end
    beta_max = if length(betas) == 0
        NaN
    else
        maximum(betas)
    end
    beta_quantiles = if length(betas) == 0
        repeat([NaN], 9)
    else
        quantile(betas, [0.025, 0.05, 0.10, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975])
    end

    DBInterface.execute(db, """
        INSERT INTO output VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, vcat(
        [
            t_output, # time
            sum(ms.state .== H),
            get_lifetime_avg(s, H),
            sum(ms.state .== A),
            get_lifetime_avg(s, A),
            sum(ms.state .== F),
            get_lifetime_avg(s, F),
            sum(ms.state .== D),
            get_lifetime_avg(s, D)
        ],
        [beta_mean, beta_sd, beta_min, beta_max],
        beta_quantiles
    ))
end

function write_animation_frame(s::Simulation, frame_id::Int64)
    save(
        joinpath("state_images", @sprintf("%d.png", frame_id)),
        make_state_image(s)
    )
    save(
        joinpath("beta_images", @sprintf("%d.png", frame_id)),
        make_beta_image(s)
    )
end

function make_state_image(s::Simulation)
    p = s.params
    state = s.model_state.state

    H_color = RGB(p.H_color...)
    A_color = RGB(p.A_color...)
    F_color = RGB(p.F_color...)
    D_color = RGB(p.D_color...)

    function convert(x)
        if x == H
            H_color
        elseif x == A
            A_color
        elseif x == F
            F_color
        elseif x == D
            D_color
        else
            error("BLAH BLAH")
        end
    end

    convert.(state)
end

function make_beta_image(s::Simulation)
    p = s.params
    is_H = s.model_state.state .== H

    bg_color = RGB(p.beta_bg_color...)

    # println(findall((s.model_state.beta .== 0.0) .!= (s.model_state.state .!= H)))
    # @assert all((s.model_state.beta .== 0.0) .== (s.model_state.state .!= H))

    betas = s.model_state.beta
    qbetas = quantile(betas[is_H], [0.05, 0.95])
    function convert(beta)
        if beta > 0.0
            val01 = clamp((beta - qbetas[1]) / (qbetas[2] - qbetas[1]), 0, 1)
            rgb = p.beta_min_color .+ (p.beta_max_color .- p.beta_min_color) .* val01

            RGB(rgb...)
        else
            bg_color
        end
    end

    convert.(betas)
end

function get_lifetime_avg(s::Simulation, state::Int64)
    s.lifetime_sums[state] / s.lifetime_counts[state]
end

function apply_offset(loc, offset, L)
    (
        wrap_coord(loc[1] + offset[1], L),
        wrap_coord(loc[2] + offset[2], L),
    )
end

function wrap_coord(x, L)
    if x == 0
        L
    elseif x == L + 1
        1
    else
        @assert 1 <= x <= L
        x
    end
end

nothing
