####################################################################
#  Insert Operator 
####################################################################

struct InsertOperator{S<:SmallSet}
    x::Int
    y::Int
    T::S   # subset of neighborsY \ adjacenciesX
    neighborsY::S
    parentsY::S
    NAyx::S
    cliqueFlag::Bool
    pathFlag::Bool
    scoreDelta::Float64
end


function InsertOperator(g,x,y)
    
    ∅ = SmallSet{maxDegree(g),Int}()
    
    #These stay the same for all x,y
    neighborsY = neighbors(g,y)
    parentsY = parents(g,y)
    NAyx = neighborsY ∩ adjacencies(g,x)
    
    return InsertOperator(x, y, ∅, neighborsY, parentsY, NAyx, false, false, -Inf)
end


function Base.show(io::IO, op::InsertOperator)
    print(io,"InsertOperator($(op.x) → $(op.y))")
end

####################################################################
#  Delete Operator 
####################################################################

struct DeleteOperator{S<:SmallSet}
    x::Int
    y::Int
    H::S   # subset of Ne(y) ∩ Ad(x)
    neighborsY::S
    parentsY::S
    NAyx::S
    scoreDelta::Float64
end


function DeleteOperator(g,x,y)
    
    ∅ = SmallSet{maxDegree(g),Int}()
    
    #These stay the same for all x,y
    neighborsY = neighbors(g,y)
    parentsY = parents(g,y)
    NAyx = neighborsY ∩ adjacencies(g,x)
    
    return DeleteOperator(x, y, ∅, neighborsY, parentsY, NAyx, -Inf)
end


function Base.show(io::IO, op::DeleteOperator)
    print(io,"DeleteOperator($(op.x) -/→ $(op.y))")
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

