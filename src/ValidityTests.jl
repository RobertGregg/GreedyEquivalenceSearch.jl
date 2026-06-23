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