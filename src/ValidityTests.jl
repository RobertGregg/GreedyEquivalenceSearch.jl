"""
Insert validity (Chickering 2002, Theorem 15):
Insert(x, y, T) is valid in CPDAG G iff:
1. NAyxT is a clique 
2. Every undirected path between x and y is blocked by NAyxT.
"""
function isValid(g, op::InsertOperator)

    (; x, y, T) = op

    isAdjacent(g, x, y) && return false

    NAyxT = neighbors(g, y) ∩ adjacencies(g, x) ∪ T

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
function isValid(g, op::DeleteOperator)

    (; x, y, H, NAyx) = op

    #Not valid if there is no edge to delete
    isAdjacent(g, x, y) || return false

    #If NAyx \ H is a clique, then valid
    return isClique(g, setdiff(NAyx, H))
end


"""
Turn validity (Hauser 2012, Proposition 34):
Turn(x, y, T) is valid iff:
1. y ∈ Pa(x) 
2. NAyxT is a clique 
3. All semi-directed paths from y to x other than (y, x) are blocked by NAyxT ∪ Ne(x)
"""
function isValid(g, op::TurnOperator)

    (; x, y, T, NAyx) = op

    #If y is not a parent of x, then invalid
    isParent(g, y, x) || return false

    NAyxT = NAyx ∪ T

    #If NAyxT not a clique, then invalid
    isClique(g, NAyxT) || return false

    #If blocking, then valid
    #TODO how do you avoid the x-y edge?
    return isBlocked(g, x, y, NAyxT ∪ neighbors(g, x))
end