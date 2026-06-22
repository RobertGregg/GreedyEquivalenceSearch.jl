####################################################################
#  Insert Operator 
####################################################################

struct InsertOperator{S<:AbstractSet}
    x::Int
    y::Int
    T::S   # subset of neighborsY \ adjacenciesX
    parentsY::S
    scoreDelta::Float64
end


function InsertOperator(g, x, y)

    parentsY = parents(g, y)
    ∅ = empty(parentsY)
    return InsertOperator(x, y, ∅, parentsY, -Inf)
end



function Base.show(io::IO, op::InsertOperator)
    print(io, "InsertOperator($(op.x) → $(op.y))")
end

####################################################################
#  Delete Operator 
####################################################################

struct DeleteOperator{S<:AbstractSet}
    x::Int
    y::Int
    H::S   # subset of Ne(y) ∩ Ad(x)
    parentsY::S
    NAyx::S
    scoreDelta::Float64
end


function DeleteOperator(g, x, y)

    ∅ = empty(parents(g, x))

    #These stay the same for all x,y
    parentsY = parents(g, y)
    NAyx = neighbors(g, y) ∩ adjacencies(g, x)

    return DeleteOperator(x, y, ∅, parentsY, NAyx, -Inf)
end


function Base.show(io::IO, op::DeleteOperator)
    print(io, "DeleteOperator($(op.x) -/→ $(op.y))")
end

####################################################################
#  Operator properties
####################################################################

#Uses BangBang.jl
setT(op::InsertOperator, T) = setproperties!!(op; T)
setH(op::DeleteOperator, H) = setproperties!!(op; H)
setScore(op, scoreDelta) = setproperties!!(op; scoreDelta) #works for both operators


#Used to compare operators based on score
Base.isless(a::InsertOperator, b::InsertOperator) = a.scoreDelta < b.scoreDelta
Base.isless(a::DeleteOperator, b::DeleteOperator) = a.scoreDelta < b.scoreDelta