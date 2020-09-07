import Base.insert!, Base.rand

mutable struct ArraySet{T}
    array::Array{T}
    indexes::Dict{T, Int64}
    
    function ArraySet{T}() where {T}
        new([], Dict{T, Int64}())
    end
end

function insert!(as::ArraySet{T}, x::T) where {T}
    push!(as.array, x)
    as.indexes[x] = lastindex(as.array)
end

function remove!(as::ArraySet{T}, x::T) where {T}
    a = as.array
    index = as.indexes[x]
    if index != lastindex(a)
        a[index] = a[lastindex(a)]
        as.indexes[a[index]] = index
    end
    pop!(a)
    delete!(as.indexes, x)
    nothing
end

function rand(rng::MersenneTwister, as::ArraySet{T}) where {T}
    rand(rng, as.array)
end

function length(as::ArraySet{T}) where {T}
    length(as.array)
end

function Vector{T}(n::Int64) where {T}
    x = Vector{T}()
    for i = 1:n
        push!(x, T())
    end
    x
end
