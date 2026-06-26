#Define an abstract type for all operators. This is useful for the isless definitions 
abstract type AbstractOperator end

####################################################################
#  Insert Operator 
####################################################################

struct InsertOperator{S<:AbstractSet} <: AbstractOperator
    x::Int
    y::Int
    T::S   # subset of neighborsY \ adjacenciesX
    NAyx::S
    parentsY::S
    scoreDelta::Float64
end


function InsertOperator(g, x, y)

    parentsY = parents(g, y)
    NAyx = neighbors(g, y) ∩ adjacencies(g, x)
    ∅ = empty(parentsY)
    return InsertOperator(x, y, ∅, NAyx, parentsY, -Inf)
end


function Base.show(io::IO, op::InsertOperator)
    print(io, "InsertOperator($(op.x) → $(op.y))")
end

####################################################################
#  Delete Operator 
####################################################################

struct DeleteOperator{S<:AbstractSet} <: AbstractOperator
    x::Int
    y::Int
    H::S   # subset of Ne(y) ∩ Ad(x)
    NAyx::S
    parentsY::S
    scoreDelta::Float64
end


function DeleteOperator(g, x, y)

    ∅ = empty(parents(g, x))

    #These stay the same for all x,y
    parentsY = parents(g, y)
    NAyx = neighbors(g, y) ∩ adjacencies(g, x)

    return DeleteOperator(x, y, ∅, NAyx, parentsY, -Inf)
end


function Base.show(io::IO, op::DeleteOperator)
    print(io, "DeleteOperator($(op.x) -/→ $(op.y))")
end


####################################################################
#  Turn Operator
####################################################################

struct TurnOperator{S<:AbstractSet} <: AbstractOperator
    x::Int
    y::Int
    T::S
    NAyx::S
    parentsX::S
    parentsY::S
    scoreDelta::Float64
end


function TurnOperator(g, x, y)

    parentsY = parents(g, y)
    parentsX = parents(g, x)
    NAyx = neighbors(g, y) ∩ adjacencies(g, x)
    ∅ = empty(parentsY)
    return TurnOperator(x, y, ∅, NAyx, parentsX, parentsY, -Inf)
end

function Base.show(io::IO, op::TurnOperator)
    print(io, "TurnOperator($(op.x) ↺ $(op.y))")
end



####################################################################
#  Operator properties
####################################################################

#Union splitting good for 3 types or less. Useful for creating vectors of mixed operators
const Operator{S<:AbstractSet} = Union{InsertOperator{S}, DeleteOperator{S}, TurnOperator{S}}

#Uses setproperties!! from BangBang
setT(op::AbstractOperator, T) = setproperties!!(op; T)
setH(op::AbstractOperator, H) = setproperties!!(op; H)
setScore(op::AbstractOperator, scoreDelta) = setproperties!!(op; scoreDelta)

# DeleteOperator (3) > TurnOperator (2) > InsertOperator (1)
# Define priorities based on the abstract type (kind of like a dict)
priority(::Type{<:DeleteOperator}) = 3
priority(::Type{<:TurnOperator})   = 2
priority(::Type{<:InsertOperator}) = 1
priority(op::AbstractOperator) = priority(typeof(op))

#Operators are the same, use score then x then y to define odering
function Base.isless(a::T, b::T) where T<:AbstractOperator
    return (a.scoreDelta, a.x, a.y) < (b.scoreDelta, b.x, b.y)
end

#Operators are different, use priority
Base.isless(a::AbstractOperator, b::AbstractOperator) = priority(a) < priority(b)