####################################################################
#  Operator structs + validity checks
####################################################################


struct InsertOperator{S<:SmallSet}
    x::Int
    y::Int
    T::S   # subset of neighborsY \ adjacenciesX
    neighborsY::S
    parentsY::S
    NAyx::S
    scoreDelta::Float64
end

function Base.show(io::IO, op::InsertOperator)
    print(io,"InsertOperator($(op.x) → $(op.y))")
end



function InsertOperator(g,x,y)
    
    ∅ = SmallSet{maxDegree(g),Int}()
    
    #These stay the same for all x,y
    neighborsY = neighbors(g,y)
    parentsY = parents(g,y)
    NAyx = neighborsY ∩ adjacencies(g,x)
    
    return InsertOperator(x, y, ∅, neighborsY, parentsY, NAyx, -Inf)
end

setT(op::InsertOperator, T) = setproperties!!(op; T)
setScore(op, scoreDelta) = setproperties!!(op; scoreDelta) #works for both operators


struct DeleteOperator{S<:SmallSet}
    x::Int
    y::Int
    H::S   # subset of Ne(y) ∩ Ad(x)
    neighborsY::S
    parentsY::S
    NAyx::S
    scoreDelta::Float64
end

function Base.show(io::IO, op::DeleteOperator)
    print(io,"DeleteOperator($(op.x) -/→ $(op.y))")
end

function DeleteOperator(g,x,y)
    
    ∅ = SmallSet{maxDegree(g),Int}()
    
    #These stay the same for all x,y
    neighborsY = neighbors(g,y)
    parentsY = parents(g,y)
    NAyx = neighborsY ∩ adjacencies(g,x)
    
    return DeleteOperator(x, y, ∅, neighborsY, parentsY, NAyx, -Inf)
end

setH(op::DeleteOperator ,H) = setproperties!!(op; H)


#Used to compare operators based on score
Base.isless(a::InsertOperator, b::InsertOperator) = a.scoreDelta < b.scoreDelta
Base.isless(a::DeleteOperator, b::DeleteOperator) = a.scoreDelta < b.scoreDelta



"""
Insert validity (Chickering 2002, Theorem 15):
Insert(x, y, T) is valid in CPDAG G iff:
1. x and y are not adjacent.
2. NAyxT is a clique in G
4. Every undirected path between x and y is blocked by NAyxT.
"""
function isValidInsert(g, op::InsertOperator)
    
    (; x, y, T, NAyx) = op
    
    #If x and y are adjacent then invalid
    isAdjacent(g, x, y) && return false

    NAyxT = NAyx ∪ T

    #If NAyxT not a clique, then invalid
    isClique(g, NAyxT) || return false
    
    #If blocking, then valid
    return isBlocked(g, x, y, NAyxT)
end


"""
Delete validity (Chickering 2002, Theorem 17):
Delete(x, y, H) is valid iff:
1. x and y are adjacent.
2. NAyx ∖ H is a clique.
"""
function isValidDelete(g, op::DeleteOperator)
    
    (; x, y, H, NAyx) = op

    #If x and y are not adjacent, then invalid
    isAdjacent(g, x, y) || return false
    
    #If NAyx \ H is a clique, then valid
    return isClique(g, setdiff(NAyx, H))
end