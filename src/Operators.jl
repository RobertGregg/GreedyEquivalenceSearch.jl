####################################################################
#  Insert Operator 
####################################################################

struct InsertOperator{S<:AbstractSet}
    x::Int
    y::Int
    T::S   # subset of neighborsY \ adjacenciesX
    E::S
    scoreDelta::Float64
end

function InsertOperator(g, x, y)

    E = parents(g,y)
    ∅ = empty(E)

    return InsertOperator(x, y, ∅, E, -Inf)
end


function InsertOperator(g, x, y, T, score)

    E = (neighbors(g, y) ∩ adjacencies(g, x)) ∪ T ∪ parents(g, y)

    scoreDelta = score(y, push(E, x)) - score(y, E)

    return InsertOperator(x, y, T, E, scoreDelta)
end



function Base.show(io::IO, op::InsertOperator)

    scoreRounded = round(op.scoreDelta, digits=3)
    print(io, "InsertOperator($(op.x) → $(op.y), T=$(collect(op.T)), E=$(collect(op.E)), score=$scoreRounded)")

end

####################################################################
#  Delete Operator 
####################################################################

struct DeleteOperator{S<:AbstractSet}
    x::Int
    y::Int
    C::S
    E::S
    scoreDelta::Float64
end


function DeleteOperator(g, x, y)

    E = parents(g,y)
    ∅ = empty(E)

    return DeleteOperator(x, y, ∅, E, -Inf)
end

function DeleteOperator(g, x, y, C, score)

    E = C ∪ parents(g, y)

    scoreDelta = score(y, setdiff(E, x)) - score(y, E)

    return DeleteOperator(x, y, C, E, scoreDelta)
end


function Base.show(io::IO, op::DeleteOperator)
    scoreRounded = round(op.scoreDelta, digits=3)
    print(io, "DeleteOperator($(op.x) -/→ $(op.y), C=$(collect(op.C)), E=$(collect(op.E)), score=$scoreRounded)")

end


####################################################################
#  Reverse Operator 
####################################################################

struct ReverseOperator{S<:AbstractSet}
    x::Int
    y::Int
    T::S
    E::S
    F::S
    scoreDelta::Float64
end

function ReverseOperator(g, x, y, C, score)

    E = C ∪ parents(g, y)

    scoreDelta = score(y, setdiff(E, x)) - score(y, E)

    return DeleteOperator(x, y, C, E, scoreDelta)
end

####################################################################
#  Operator properties
####################################################################

#Union splitting good for 3 or less types
const Operator{S<:AbstractSet} = Union{InsertOperator{S},DeleteOperator{S}}


#Used to compare operators based on score
Base.isless(a::DeleteOperator, b::InsertOperator) = false
Base.isless(a::InsertOperator, b::DeleteOperator) = true

function Base.isless(a::Operator, b::Operator)
    # 1. Primary sort key
    if a.scoreDelta ≠ b.scoreDelta
        return isless(a.scoreDelta, b.scoreDelta)
    end

    # 2. Tie-breaker 1: Compare the transition mapping
    if a.y ≠ b.y
        return isless(a.y, b.y)
    end
    if a.x ≠ b.x
        return isless(a.x, b.x)
    end

    # 3. Tie-breaker 2: Compare other distinguishing fields
    return isless(a.E, b.E)
end



#Uses BangBang.jl
setT(op::InsertOperator, T) = setproperties!!(op; T)
setC(op::DeleteOperator, C) = setproperties!!(op; C)
setE(op::Operator, E) = setproperties!!(op; E)
setScore(op, scoreDelta) = setproperties!!(op; scoreDelta) #works for both operators
