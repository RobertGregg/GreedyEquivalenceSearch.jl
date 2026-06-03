

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



####################################################################
#  Precheck Optimizations for InsertOperator
####################################################################

# 1. If the neighbors of y have not changed, the clique validity condition must hold true for all previouly valid operators. Because we are adding edges, any previous clique remains a clique

function precheckClique(g, op)
    neighbors(g, op.y) == op.neighborsY
end