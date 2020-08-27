using Random
using StatsBase

### PARAMETERS

mutable struct Parameters
    rng_seed::Union{Int64, Nothing}
    
    L::Int64
    
    k::Float64
    r::Float64
    
    t_final::Float64
    t_output::Float64
    
    function Parameters()
        p = new()
        
        p.rng_seed = nothing
        p.L = 200
        
        p.k = 0.01
        p.r = 0.05
        
        p.t_final = 10000
        p.t_output = 1
        
        p
    end
end
JSON2.@format Parameters noargs


### CONSTANTS

# Site states
const H = 1
const A = 2
const F = 3
const D = 4

# Events
const LOCAL_FH = 1
const GLOBAL_FH = 2
const AD = 3
const HD = 4
const FA = 5
const DF = 6
const BETA_CHANGE = 7
EVENTS = [LOCAL_FH, GLOBAL_FH, AD, HD, FA, DF, BETA_CHANGE]


### SIMULATION STATE AND INITIALIZATION

Loc = Tuple{Int64, Int64}
LocVec = Vector{Loc}

struct Site
    state::Int64
    beta::Union{Float64, Nothing}
    
    function Site()
        Site(0)
    end
    
    function Site(state::Int64)
        @assert state != H
        new(state, nothing)
    end
    
    function Site(state::Int64, beta::Float64)
        @assert state == H
        new(H, beta)
    end
end

mutable struct Simulation
    params::Parameters
    rng::MersenneTwister
    t::Float64
    
    sites::Matrix{Site}
    sites_by_state::Vector{LocVec}
    
    event_rates::Vector{Float64}
    event_weights::Weights
    
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
        s.sites_by_state = [ [], [], [], [] ]
        
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
    s.sites[locH, locH] = Site(H, 1.0)
    push!(s.sites_by_state[H], (locH, locH))
    
    # Initialize every other site as forest 
    for j in 1:L
        for i in 1:L
            if s.sites[i, j].state == 0
                s.sites[i, j] = Site(F)
                push!(s.sites_by_state[F], (i, j))
            end
        end
    end
    
    @assert length(s.sites_by_state[H]) == 1
    @assert length(s.sites_by_state[F]) == L * L - 1
    
    update_rates!(s)
end


### SIMULATION CONVENIENCE FUNCTIONS

function state_count(sim::Simulation, state::Int64)
    return length(sim.sites_by_state[state])
end

function draw_site_in_state(s::Simulation, state::Int64)
    @assert state_count(s, state) > 0
    rand(s.rng, s.sites_by_state[state])
end


### SIMULATION LOOP

function simulate(s::Simulation)
    p = s.params
    
    # Repeatedly do events
    t_next_output = 0.0
    while s.t < p.t_final
    
        # Draw next event time using total rate
        @debug "event_rates" s.event_rates
        t_next = s.t + randexp(s.rng) / sum(s.event_weights)
        @debug "t_next" t_next
        
        # If the next event is after the output time, we need to do some output
        while t_next >= t_next_output
            do_output(s, t_next_output)
            t_next_output += p.t_output
        end
    
        # Sample next event category proportional to event rate
        event_id = sample(s.rng, EVENTS, s.event_weights)
        @debug "event_id" event_id

        # Perform event and update all rates
        event_occurred = do_event!(event_id, s, t_next)
        if event_occurred
            update_rates!(s)
        end
    
        s.t = t_next
    end
end

function do_output(s::Simulation, t_output)
    println("Outputting at ", t_output)
end

function update_rates!(sim::Simulation)
    for i = EVENTS
        sim.event_rates[i] = get_rate(EVENTS[i], sim)
    end
    sim.event_weights = Weights(sim.event_rates)
end

function update_rate!(event_id, sim::Simulation)
    sim.event_rates[event_id] = get_rate(event_id, sim)
end


### EVENT DISPATCH

# This could all be done with Val + multiple dispatch,
# but this is easier to understand for Julia newbies.

function get_rate(event_id, sim::Simulation)
    if event_id == LOCAL_FH
        get_rate_local_FH(sim)
    elseif event_id == GLOBAL_FH
        get_rate_global_FH(sim)
    elseif event_id == AD
        get_rate_AD(sim)
    elseif event_id == HD
        get_rate_HD(sim)
    elseif event_id == FA
        get_rate_FA(sim)
    elseif event_id == DF
        get_rate_DF(sim)
    elseif event_id == BETA_CHANGE
        get_rate_beta_change(sim)
    end
end

function do_event!(event_id, sim::Simulation, t::Float64)
    if event_id == LOCAL_FH
        do_event_local_FH!(sim, t)
    elseif event_id == GLOBAL_FH
        do_event_global_FH!(sim, t)
    elseif event_id == AD
        do_event_AD!(sim, t)
    elseif event_id == HD
        do_event_HD!(sim, t)
    elseif event_id == FA
        do_event_FA!(sim, t)
    elseif event_id == DF
        do_event_DF!(sim, t)
    elseif event_id == BETA_CHANGE
        do_event_beta_change!(sim)
    end
end


### LOCAL COLONIZATION (F -> H)

function alpha_max(r)
    return 1.0 / (1.0 + r)
end

function get_rate_local_FH(s::Simulation)
    p = s.params
    
    return (1.0 - p.k) * state_count(s, H) * 8.0 * alpha_max(p.r)
end

function do_event_local_FH!(s::Simulation, t)
    p = s.params
    
    # Draw a random human to do the colonizing
    @assert state_count(s, H) > 0
    x, y = draw_site_in_state(s, H)
    @debug "x, y", x, y
    
    false
end


### GLOBAL COLONIZATION (F -> H)

function get_rate_global_FH(sim)
    return 0.0
end

function do_event_global_FH!(sim, t)
    false
end


### AGRICULTURAL DEGRADATION (A -> D)

function get_rate_AD(sim)
    return 0.0
end

function do_event_AD!(sim, t)
    false
end


### ABANDONMENT (H -> D)

function get_rate_HD(sim)
    return 0.0
end

function do_event_HD!(sim, t)
end


### CONVERSION TO AGRICULTURE (F -> A)

function get_rate_FA(sim)
    return 0.0
end

function do_event_FA!(sim, t)
    false
end


### RECOVERY OF DEGRADED LAND (D -> F)

function get_rate_DF(sim)
    return 0.0
end

function do_event_DF!(sim, t)
    false
end


### BETA CHANGE

function get_rate_beta_change(sim)
    return 0.0
end

function do_event_beta_change!(sim, t)
    false
end
