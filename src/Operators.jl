####################################################################
#  Operator structs + validity checks
####################################################################


struct InsertOperator{S<:SmallSet}
    x::Int
    y::Int
    T::S   # subset of neighborsY \ adjacenciesX
    neighborsY::S
    adjacenciesX::S
    scoreDelta::Float64
end

InsertOperator(x,y,T,neighborsY,adjacenciesX) = InsertOperator(x,y,T,neighborsY,adjacenciesX,-Inf)
InsertOperator(g,x,y) = InsertOperator(x,y,SmallSet{maxDegree(g),Int}(),neighbors(g,y),adjacencies(g,x),-Inf)

struct DeleteOperator{S<:SmallSet}
    x::Int
    y::Int
    H::S   # subset of Ne(y) ∩ Ad(x)
    neighborsY::S
    adjacenciesX::S
    scoreDelta::Float64
end

DeleteOperator(x,y,H,neighborsY,adjacenciesX) = DeleteOperator(x,y,H,neighborsY,adjacenciesX,-Inf)
DeleteOperator(g,x,y) = DeleteOperator(x,y,SmallSet{maxDegree(g),Int}(),neighbors(g,y),adjacencies(g,x),-Inf)

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
    
    (; x, y, T, neighborsY, adjacenciesX) = op
    
    #If x and y are adjacent then invalid
    isAdjacent(g, x, y) && return false

    NAyxT = neighborsY ∩ adjacenciesX ∪ T

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
    
    (; x, y, H, neighborsY, adjacenciesX) = op

    #If x and y are not adjacent, then invalid
    isAdjacent(g, x, y) || return false
    
    # H is a subset of Ne(y) ∩ Ad(x)
    NAyx = neighborsY ∩ adjacenciesX
    
    #If NAyx \ H is a clique, then valid
    return isClique(g, setdiff(NAyx, H))
end