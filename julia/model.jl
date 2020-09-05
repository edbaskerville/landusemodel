import Base.length
using Random
using StatsBase
using DataStructures: SortedDict

include("util.jl")

### PARAMETERS

@enum ProductivityFunction begin
    PRODUCTIVITY_A
    PRODUCTIVITY_AF
end

mutable struct Parameters
    rng_seed::Union{Int64, Nothing}
    
    L::Int64
    
    productivityFunction::ProductivityFunction
    
    k::Float64
    r::Float64
    
    deltaF::Bool
    q::Float64
    
    c::Float64
    m::Float64
    
    epsilonF::Bool
    epsilon::Float64
    
    sigma::Float64
    
    maxTime::Float64
    logInterval::Float64
    
    function Parameters()
        p = new()
        
        p.rng_seed = nothing
        p.L = 200
        
        p.productivityFunction = PRODUCTIVITY_A
        
        p.k = 0.0
        p.r = 0.05
        
        p.deltaF = true
        p.q = 1.0
        
        p.c = 0.001
        p.m = 0.2
        
        p.epsilonF = false
        p.epsilon = 6.0
        
        p.sigma = 0.2
        
        p.maxTime = 10000
        p.logInterval = 1
        
        p
    end
end
JSON2.@format Parameters noargs


### CONSTANTS

# Site states
STATES = Vector(1:4)
const H, A, F, D = STATES
println(STATES)
println(length(STATES))

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
    state::Int64
    beta::Union{Float64, Nothing}
    
    function Site()
        Site(0, 0)
    end
    
    function Site(state::Int64)
        Site(state, nothing)
    end
    
    function Site(state::Int64, beta::Union{Float64, Nothing})
        if beta === nothing
            @assert state != H
        end
        
        new(state, beta)
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
    set_state!(s, (locH, locH), H, 1.0)
    
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
    
    # Remove from sites_by_state set for old state
    if site.state != 0 && site.state != state
        remove!(s.sites_by_state[site.state], loc)
    end
    
    # Insert into sites_by_state set for new state
    if site.state == 0 || site.state != state
        insert!(s.sites_by_state[state], loc)
    end
    
    s.sites[loc_index] = Site(state, beta)
    
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
    
    # Repeatedly do events
    t_next_output = 0.0
    while s.t < p.maxTime
        R = sum(s.event_rates)
        
        # Draw next event time using total rate
        @debug "event_rates" s.event_rates
        t_next = if R == 0.0
            p.maxTime
        else
            s.t + randexp(s.rng) / sum(s.event_weights)
        end
        @debug "t_next" t_next
        
        # If the next event is after the output time, we need to do some output
        while t_next >= t_next_output
            do_output(s, t_next_output)
            t_next_output += p.logInterval
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

function do_output(s::Simulation, t_output)
    println("Outputting at ", t_output)
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


### LOCAL COLONIZATION (F -> H) ###

function get_rate_local_FH(s::Simulation)
    p = s.params
    
    return (1.0 - p.k) * state_count(s, H) * 8.0 * max_site_rate_FH(s)
end

function do_event_local_FH!(s::Simulation, t)
    @debug "do_event_local_FH!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random human to do the colonizing
    @assert state_count(s, H) > 0
    loc_H = draw_location_in_state(s, H)
    site_H = get_site(s, loc_H)
    @debug "loc_H", loc_H
    
    # Draw a random neighbor of the inhabited site
    loc_neighbor = draw_neighbor(s, loc_H)
    @debug "loc_neighbor", loc_neighbor
    
    # If neighbor is in state F, transition to state H
    @debug "neighbor state" get_state(s, loc_neighbor)
    if get_state(s, loc_neighbor) == F
        @debug "neighbor is F"
        
        # Perform event with probability site_rate / max_site_rate (rejection method)
        if rand(rng) < get_site_rate_FH(s, loc_H) / max_site_rate_FH(s)
            @debug "actually doing F -> H"
            set_state!(s, loc_neighbor, H, site_H.beta)
            true
        else
            @debug "not doing F -> H"
            false
        end
    else
        false
    end
end

function max_site_rate_FH(s)
    return 1.0 / (1.0 + s.params.r)
end

function get_site_rate_FH(s::Simulation, loc::Tuple{Int64, Int64})
    a = if s.params.productivityFunction == PRODUCTIVITY_A
        get_productivity_A(s, loc)
    else
        get_productivity_AF(s, loc)
    end
    
    a / (a + s.params.r)
end

function get_productivity_A(s::Simulation, loc::Tuple{Int64, Int64})
    get_neighbor_count(s, loc, A) / 8.0
end

function get_productivity_AF(s::Simulation, loc::Tuple{Int64, Int64})
    @assert false
    0.0
end


### GLOBAL COLONIZATION (F -> H)

function get_rate_global_FH(s)
    @assert s.params.k == 0.0
    
    return 0.0
end

function do_event_global_FH!(s, t)
    false
end


### AGRICULTURAL DEGRADATION (A -> D)

function get_rate_AD(s::Simulation)
    @assert s.params.deltaF
    
    return state_count(s, A) * max_site_rate_AD(s)
end

function do_event_AD!(s, t)
    @debug "do_event_AD!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random agricultural location
    @assert state_count(s, A) > 0
    loc = draw_location_in_state(s, A)
    @debug "loc", loc
    
    # Perform event with probability site_rate / max_site_rate (rejection method)
    if rand(rng) < get_site_rate_AD(s, loc) / max_site_rate_AD(s)
        @debug "actually doing A -> D"
        set_state!(s, loc, D)
        true
    else
        false
    end
end

function max_site_rate_AD(s)
    return 1.0
end

function get_site_rate_AD(s, loc)
    p = s.params
    q = p.q
    m = p.m
    
    fq = (get_neighbor_count(s, loc, F) / 8.0)^q
    
    1.0 - fq / (fq + m)
end


### ABANDONMENT (H -> D) ###

function get_rate_HD(s)
    @assert s.params.deltaF
    
    return state_count(s, H) * max_site_rate_HD(s)
end

function do_event_HD!(s, t)
    @debug "do_event_HD!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random human location
    @assert state_count(s, H) > 0
    loc = draw_location_in_state(s, H)
    @debug "loc", loc
    
    # Perform event with probability site_rate / max_site_rate (rejection method)
    if rand(rng) < get_site_rate_HD(s, loc) / max_site_rate_HD(s)
        @debug "actually doing H -> D"
        set_state!(s, loc, D)
        true
    else
        false
    end
end

function max_site_rate_HD(s)
    return 1.0
end

function get_site_rate_HD(s, loc)
    p = s.params
    c = p.c
    
    a = get_neighbor_count(s, loc, A) / 8.0
    
    1.0 - a / (a + c)
end


### CONVERSION TO AGRICULTURE (F -> A) ###

function get_rate_FA(s)
    return state_count(s, H) * 8.0 * max_beta(s)
end

function do_event_FA!(s, t)
    @debug "do_event_FA!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random human to do the conversion
    @assert state_count(s, H) > 0
    loc_H = draw_location_in_state(s, H)
    site_H = get_site(s, loc_H)
    @debug "loc_H", loc_H
    
    # Draw a random neighbor of the inhabited site
    loc_neighbor = draw_neighbor(s, loc_H)
    @debug "loc_neighbor", loc_neighbor
    
    # If neighbor is in state F, transition to state A
    @debug "neighbor state" get_state(s, loc_neighbor)
    if get_state(s, loc_neighbor) == F
        @debug "neighbor is F"
        
        # Perform event with probability beta / max_beta (rejection method)
        if rand(rng) < site_H.beta / max_beta(s)
            @debug "actually doing F -> A"
            set_state!(s, loc_neighbor, A)
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
    @assert !s.params.epsilonF
    
    return state_count(s, D) * s.params.epsilon
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
    return state_count(s, H) * s.params.sigma
end

function do_event_beta_change!(s, t)
    @debug "do_event_beta_change!", t
    
    p = s.params
    rng = s.rng
    
    # Draw a random inhabited location
    @assert state_count(s, H) > 0
    loc = draw_location_in_state(s, H)
    site = get_site(s, loc)
    beta = max(0.0, site.beta + randn(rng) * 0.01)
    
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
