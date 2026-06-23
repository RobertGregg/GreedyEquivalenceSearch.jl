####################################################################
#  Insert Operator 
####################################################################

struct InsertOperator{S<:AbstractSet}
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

struct DeleteOperator{S<:AbstractSet}
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
#  Operator properties
####################################################################

setT(op::InsertOperator, T) = InsertOperator(op.x, op.y, T, op.NAyx, op.parentsY, op.scoreDelta)
setH(op::DeleteOperator, H) = DeleteOperator(op.x, op.y, H, op.NAyx, op.parentsY, op.scoreDelta)

setScore(op::InsertOperator, scoreDelta) = InsertOperator(op.x, op.y, op.T, op.NAyx, op.parentsY, scoreDelta)
setScore(op::DeleteOperator, scoreDelta) = DeleteOperator(op.x, op.y, op.H, op.NAyx, op.parentsY, scoreDelta)

#Used to compare operators based on score
Base.isless(a::InsertOperator, b::InsertOperator) = a.scoreDelta < b.scoreDelta
Base.isless(a::DeleteOperator, b::DeleteOperator) = a.scoreDelta < b.scoreDelta

Base.isless(a::InsertOperator, b::DeleteOperator) = true
Base.isless(a::DeleteOperator, b::InsertOperator) = false