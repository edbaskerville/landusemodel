import Base.length
using Random
using Statistics
using StatsBase
using DataStructures: SortedDict
using Images
using FileIO
using Printf
using SQLite

include("util.jl")

### PARAMETERS

@enum FHProbabilityFunction begin
    FH_A
    FH_AF
end

mutable struct Parameters
    rng_seed::Union{Int64, Nothing}
    
    L::Int64
    
    t_final::Float64
    t_output::Float64
    
    max_rate_FH::Float64
    frac_global_FH::Float64
    
    max_rate_AD::Float64
    min_rate_frac_AD::Float64
    
    max_rate_HD::Float64
    min_rate_frac_HD::Float64
    
    rate_DF::Float64
    
    beta_initial::Float64
    sd_log_beta::Float64
    rate_beta_change::Float64
    
    probability_function_FH::FHProbabilityFunction
    
#     H_color: Tuple{Float64, Float64, Float64}
#     A_color: Tuple{Float64, Float64, Float64}
#     F_color: Tuple{Float64, Float64, Float64}
#     D_color: Tuple{Float64, Float64, Float64}
    
    enable_animation::Bool
    t_animation_frame::Float64
    
    function Parameters()
        p = new()
        
        p.rng_seed = nothing
        p.L = 200
        
        p.t_final = 10000.0
        p.t_output = 1.0
        
        p.max_rate_FH = 1.0 / 30.0
        p.frac_global_FH = 0.05
        
        p.max_rate_AD = 1.0 / 360.0
        p.min_rate_frac_AD = 0.01
        
        p.max_rate_HD = 1.0 / 360.0
        p.min_rate_frac_AD = 0.01
        
        p.rate_DF = 1.0 / 360.0
        
        p.beta_initial = 1.0 / 10.0
        p.sd_log_beta = 1.0 / 300
        p.rate_beta_change = 1.0
        
        p.enable_animation = true
        p.t_animation_frame = 30.0
        
        p.probability_function_FH = FH_A
        
        p
    end
end
JSON2.@format Parameters noargs


### CONSTANTS

# Site states
STATES = Vector(1:4)
const H, A, F, D = STATES

# Events
EVENTS = Vector(1:7)
LOCAL_FH, GLOBAL_FH, AD, HD, FA, DF, BETA_CHANGE = EVENTS
# const LOCAL_FH = 1
# const GLOBAL_FH = 2
# const AD = 3
# const HD = 4
# const FA = 5
# const DF = 6
# const BETA_CHANGE = 7
# EVENTS = [LOCAL_FH, GLOBAL_FH, AD, HD, FA, DF, BETA_CHANGE]


### SIMULATION STATE AND INITIALIZATION

Loc = Tuple{Int64, Int64}

struct Site
    t_init::Float64
    state::Int64
    beta::Union{Float64, Nothing}
    
    function Site()
        Site(0.0, 0)
    end
    
    function Site(t::Float64, state::Int64)
        Site(t, state, nothing)
    end
    
    function Site(t::Float64, state::Int64, beta::Union{Float64, Nothing})
        if beta === nothing
            @assert state != H
        end
        
        new(t, state, beta)
    end
end

mutable struct Simulation
    params::Parameters
    rng::MersenneTwister
    t::Float64
    
    sites::Matrix{Site}
    sites_by_state::Vector{ArraySet{Loc}}
    
    betas::SortedDict{Float64, Int64}
    
    event_rates::Vector{Float64}
    event_weights::Weights
    
    lifetime_sums::Vector{Float64}
    lifetime_counts::Vector{Int64}
    
    function Simulation(params::Parameters)
        s = new()
        
        s.params = deepcopy(params)
        if s.params.rng_seed === nothing
            s.params.rng_seed = Int64(rand(RandomDevice(), UInt32))
        end
        p = s.params
        
        s.rng = MersenneTwister(s.params.rng_seed)
        
        s.t = 0.0
        s.sites = Matrix{Site}(undef, p.L, p.L)
        s.sites_by_state = Vector{ArraySet{Loc}}(length(STATES))
        s.betas = SortedDict{Float64, Int64}()
        
        s.lifetime_sums = zeros(Float64, length(STATES))
        s.lifetime_counts = zeros(Int64, length(STATES))
        
        s.event_rates = repeat([0.0], length(EVENTS))
        
        initialize!(s)
        
        s
    end
end

function initialize!(s::Simulation)
    p = s.params
    L = p.L
    
    # Initialize one human site in the center of the grid
    locH = div(L, 2)
    set_state!(s, (locH, locH), H, p.beta_initial)
    
    # Initialize every other site as forest 
    for j in 1:L
        for i in 1:L
            if !(i == locH && j == locH)
                set_state!(s, (i, j), F)
            end
        end
    end
    
    @assert length(s.sites_by_state[H]) == 1
    @assert length(s.sites_by_state[F]) == L * L - 1
    
    update_rates!(s)
end


### MAX BETA TRACKING

function max_beta(s)
    if length(s.betas) > 0
        last(s.betas)[1]
    else
        0.0
    end
end

function insert_beta!(s, beta)
    if haskey(s.betas, beta)
        insert!(s.betas, beta, s.betas[beta] + 1)
    else
        insert!(s.betas, beta, 1)
    end
    nothing
end

function remove_beta!(s, beta)
    new_count = s.betas[beta] - 1
    if new_count == 0
        pop!(s.betas, beta)
    else
        insert!(s.betas, beta, new_count)
    end
    nothing
end


### SIMULATION CONVENIENCE FUNCTIONS

function get_site(s::Simulation, loc::Tuple{Int64, Int64})
    s.sites[CartesianIndex(loc)]
end

function get_state(s::Simulation, loc::Tuple{Int64, Int64})
    s.sites[CartesianIndex(loc)].state
end

function set_state!(s::Simulation, loc::Tuple{Int64, Int64}, state::Int64)
    set_state!(s, loc, state, nothing)
end

function set_state!(s::Simulation, loc::Tuple{Int64, Int64}, state::Int64, beta::Union{Float64, Nothing})
    @assert state != 0
    
    loc_index = CartesianIndex(loc)
    site = s.sites[loc_index]
    
    # Remove from sites_by_state set for old state; track lifetime
    if site.state != 0 && site.state != state
        remove!(s.sites_by_state[site.state], loc)
        s.lifetime_sums[site.state] += s.t - site.t_init
        s.lifetime_counts[site.state] += 1
    end
    
    # Insert into sites_by_state set for new state
    if site.state == 0 || site.state != state
        insert!(s.sites_by_state[state], loc)
    end
    
    if site.state == state
        s.sites[loc_index] = Site(site.t_init, state, beta)
    else
        s.sites[loc_index] = Site(s.t, state, beta)
    end
    
    # Remove old beta from beta tracking structure
    if site.state == H
        if state != H || beta != site.beta
            remove_beta!(s, site.beta)
        end
    end
    
    # Add new beta to beta tracking structure
    if state == H
        if site.state != H || beta != site.beta
            insert_beta!(s, beta)
        end
    end
end

function state_count(s::Simulation, state::Int64)
    return length(s.sites_by_state[state])
end

function draw_location_in_state(s::Simulation, state::Int64)
    @assert state_count(s, state) > 0
    rand(s.rng, s.sites_by_state[state])
end


### SIMULATION LOOP

function simulate(s::Simulation)
    p = s.params
    
    if p.enable_animation
        if isdir("images")
            error("images already exists; delete first")
        end
        mkdir("images")
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
    
    # Repeatedly do events
    t_next_output = 0.0
    t_next_frame = 0.0
    while s.t < p.t_final
        R = sum(s.event_rates)
        
        # Draw next event time using total rate
        @debug "event_rates" s.event_rates
        t_next = if R == 0.0
            p.t_final
        else
            s.t + randexp(s.rng) / sum(s.event_weights)
        end
        @debug "t_next" t_next
        
        # If the next event is after the output time, we need to do some output
        while t_next >= t_next_output
            do_output(s, db, t_next_output)
            if p.enable_animation && t_next_output == t_next_frame
                save(
                    joinpath("images", @sprintf("%d.png", Int64(t_next_frame))),
                    colorview(Gray, rand(s.rng, 200, 200))
                )
                t_next_frame += p.t_animation_frame
            end
            t_next_output += p.t_output
        end
        
        s.t = t_next
        
        if R > 0.0
            # Sample next event category proportional to event rate
            event_id = sample(s.rng, EVENTS, s.event_weights)
            @debug "event_id" event_id

            # Perform event and update all rates
            event_occurred = do_event!(event_id, s, t_next)
            if event_occurred
                update_rates!(s)
            end
        end
    end
end

function do_output(s::Simulation, db, t_output)
    println("Outputting at ", t_output)
    
    DBInterface.execute(db, """
        INSERT INTO output VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, vcat(
        [
            t_output, # time
            state_count(s, H),
            get_lifetime_avg(s, H),
            state_count(s, A),
            get_lifetime_avg(s, A),
            state_count(s, F),
            get_lifetime_avg(s, F),
            state_count(s, D),
            get_lifetime_avg(s, D)
        ],
        beta_output_values(s)
    ))
end

function beta_output_values(s::Simulation)
    betas = Vector{Float64}()
    for (beta, count) = s.betas
        for i in 1:count
            push!(betas, beta)
        end
    end
    
    beta_mean = mean(betas)
    beta_sd = std(betas, corrected = false)
    beta_min = minimum(betas)
    beta_max = maximum(betas)
    beta_quantiles = quantile(betas, [0.025, 0.05, 0.10, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975])
    
    vcat([beta_mean, beta_sd, beta_min, beta_max], beta_quantiles)
end

function get_lifetime_avg(s::Simulation, state::Int64)
    s.lifetime_sums[state] / s.lifetime_counts[state]    
end

function update_rates!(s::Simulation)
    for i = EVENTS
        s.event_rates[i] = get_rate(EVENTS[i], s)
    end
    s.event_weights = Weights(s.event_rates)
end

function update_rate!(event_id, s::Simulation)
    s.event_rates[event_id] = get_rate(event_id, s)
end


### EVENT DISPATCH ###

# This could all be done with Val + multiple dispatch,
# but this is easier to understand for Julia newbies.

function get_rate(event_id, s::Simulation)
    if event_id == LOCAL_FH
        get_rate_local_FH(s)
    elseif event_id == GLOBAL_FH
        get_rate_global_FH(s)
    elseif event_id == AD
        get_rate_AD(s)
    elseif event_id == HD
        get_rate_HD(s)
    elseif event_id == FA
        get_rate_FA(s)
    elseif event_id == DF
        get_rate_DF(s)
    elseif event_id == BETA_CHANGE
        get_rate_beta_change(s)
    end
end

function do_event!(event_id, s::Simulation, t::Float64)
    if event_id == LOCAL_FH
        do_event_local_FH!(s, t)
    elseif event_id == GLOBAL_FH
        do_event_global_FH!(s, t)
    elseif event_id == AD
        do_event_AD!(s, t)
    elseif event_id == HD
        do_event_HD!(s, t)
    elseif event_id == FA
        do_event_FA!(s, t)
    elseif event_id == DF
        do_event_DF!(s, t)
    elseif event_id == BETA_CHANGE
        do_event_beta_change!(s, t)
    end
end


### COLONIZATION (F -> H) ###

function get_rate_local_FH(s::Simulation)
    p = s.params
    
    return (1.0 - p.frac_global_FH) * state_count(s, F) * p.max_rate_FH
end

function do_event_local_FH!(s::Simulation, t)
    @debug "do_event_local_FH!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random forested site to be colonized
    @assert state_count(s, F) > 0
    loc_F = draw_location_in_state(s, F)
    @debug "loc_F", loc_F
    
    # Draw a random neighbor of the forested site
    loc_neighbor = draw_neighbor(s, loc_F)
    @debug "loc_neighbor", loc_neighbor
    
    # If neighbor is in state H, maybe transition to state H
    @debug "neighbor state" get_state(s, loc_neighbor)
    if get_state(s, loc_neighbor) == H
        @debug "neighbor is H"
        
        # Perform event with probability that depends on neighbors of H
        if rand(rng) < probability_FH(s, loc_neighbor)
            @info "actually doing local F -> H"
            set_state!(s, loc_F, H, get_site(s, loc_neighbor).beta)
            true
        else
            @debug "not doing F -> H"
            false
        end
    else
        false
    end
end

function get_rate_global_FH(s)
    p = s.params
    L = Float64(p.L)
    frac_H = state_count(s, H) / (L * L - 1.0)
    return p.frac_global_FH * state_count(s, F) * frac_H * p.max_rate_FH
end

function do_event_global_FH!(s, t)
    @debug "do_event_global_FH!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random forested site to be colonized
    @assert state_count(s, F) > 0
    loc_F = draw_location_in_state(s, F)
    @debug "loc_F", loc_F
    
    # Draw a random human anywhere on the lattice
    @assert state_count(s, H) > 0
    loc_H = draw_location_in_state(s, H)
    @debug "loc_H", loc_H
    
    # Perform event with probability that depends on neighbors of H site
    if rand(rng) < probability_FH(s, loc_H)
        @debug "actually doing global F -> H"
        set_state!(s, loc_F, H, get_site(s, loc_H).beta)
        true
    else
        @debug "not doing F -> H"
        false
    end
end

function probability_FH(s::Simulation, loc_H)
    if s.params.probability_function_FH == FH_A
        probability_FH_A(s, loc_H)
    else
        probability_FH_AF(s, loc_H)
    end
end

function probability_FH_A(s::Simulation, loc_H)
    get_neighbor_count(s, loc_H, A) / 8.0
end

function probability_FH_AF(s::Simulation, loc_H)
    sum_neighbor_density_AF
    for loc_neighbor in get_neighbors(s, loc_H)
        if get_state(s, loc_neighbor) == A
            sum_neighbor_density_AF += get_neighbor_count(s, loc_neighbor, F) / 7.0
        end
    end
    sum_neighbor_density_AF / 8.0
end


### AGRICULTURAL DEGRADATION (A -> D)

function get_rate_AD(s::Simulation)
    return state_count(s, A) * s.params.max_rate_AD
end

function do_event_AD!(s, t)
    @debug "do_event_AD!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random agricultural location
    @assert state_count(s, A) > 0
    loc = draw_location_in_state(s, A)
    @debug "loc", loc
    
    # Perform event with probability_AD
    if rand(rng) < probability_AD(s, loc)
        @debug "actually doing A -> D"
        set_state!(s, loc, D)
        true
    else
        false
    end
end

function probability_AD(s, loc)
    p = s.params
    p.min_rate_frac_AD + (1.0 - p.min_rate_frac_AD) * get_neighbor_count(s, loc, F) / 8.0
end


### ABANDONMENT (H -> D) ###

function get_rate_HD(s)
    return state_count(s, H) * s.params.max_rate_HD
end

function do_event_HD!(s, t)
    @debug "do_event_HD!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random human location
    @assert state_count(s, H) > 0
    loc = draw_location_in_state(s, H)
    @debug "loc", loc
    
    # Perform event with probability_HD
    if rand(rng) < probability_HD(s, loc)
        @debug "actually doing H -> D"
        set_state!(s, loc, D)
        true
    else
        false
    end
end

function probability_HD(s, loc)
    p = s.params
    p.min_rate_frac_HD + (1.0 - p.min_rate_frac_HD) * get_neighbor_count(s, loc, A) / 8.0
end


### CONVERSION TO AGRICULTURE (F -> A) ###

function get_rate_FA(s)
    return state_count(s, F) * max_beta(s)
end

function do_event_FA!(s, t)
    @debug "do_event_FA!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random forested site
    @assert state_count(s, F) > 0
    loc_F = draw_location_in_state(s, F)
    site_F = get_site(s, loc_F)
    @debug "loc_F", loc_F
    
    # Draw a random neighbor of the forested site
    loc_neighbor = draw_neighbor(s, loc_F)
    @debug "loc_neighbor", loc_neighbor
    
    # If neighbor is in state H, maybe transition to state A
    @debug "neighbor state" get_state(s, loc_neighbor)
    if get_state(s, loc_neighbor) == H
        @debug "neighbor is H"
        
        # Perform event with probability beta / max_beta (rejection method)
        if rand(rng) < get_site(s, loc_neighbor).beta / max_beta(s)
            @info "actually doing F -> A"
            set_state!(s, loc_F, A)
            true
        else
            @debug "not doing F -> A"
            false
        end
    else
        false
    end
end


### RECOVERY OF DEGRADED LAND (D -> F)

function get_rate_DF(s)
    return state_count(s, D) * s.params.rate_DF
end

function do_event_DF!(s, t)
    @debug "do_event_DF!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random degraded location
    @assert state_count(s, D) > 0
    loc = draw_location_in_state(s, D)
    @debug "loc", loc
    
    set_state!(s, loc, F)
    true
end


### BETA CHANGE

function get_rate_beta_change(s)
    return state_count(s, H) * s.params.rate_beta_change
end

function do_event_beta_change!(s, t)
    @debug "do_event_beta_change!", t
    
    p = s.params
    rng = s.rng
    
    # Standard deviation of random walk for an average-length timestep
    # (variance is proportional to timestep, inversely proportional to rate)
    sd2 = p.sd_log_beta * p.sd_log_beta
    sd_dt = sqrt(sd2 / p.rate_beta_change)
    
    # Draw a random inhabited location
    @assert state_count(s, H) > 0
    loc = draw_location_in_state(s, H)
    site = get_site(s, loc)
    beta = site.beta * exp(randn(rng) * sd_dt)
    
    set_state!(s, loc, H, beta)
    true
end


### UTILITY FUNCTIONS AND DATA STRUCTURES ###

NEIGHBOR_OFFSETS = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1)
]

function draw_neighbor(s::Simulation, loc::Tuple{Int64, Int64})
    offset = rand(s.rng, NEIGHBOR_OFFSETS)
    apply_offset(loc, offset, s.params.L)
end

function get_neighbor_count(s::Simulation, loc, state)
    L = s.params.L
    count = 0
    for offset = NEIGHBOR_OFFSETS
        if get_state(s, apply_offset(loc, offset, L)) == state
            count += 1
        end
    end
    count
end

function get_neighbors(s::Simulation, loc)
    L = s.params.L
    neighbors = Vector{Loc}(undef, length(NEIGHBOR_OFFSETS))
    for i = 1:lastindex(NEIGHBOR_OFFSETS)
        neighbors[i] = apply_offset(loc, NEIGHBOR_OFFSETS[i], L)
    end
    neighbors
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
