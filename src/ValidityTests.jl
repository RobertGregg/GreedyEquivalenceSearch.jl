
#These checks are independent of T and can happen outside of the powerset loop
function precheckValidInsert(g, op::InsertOperator)

    (; x, y) = op

    #Check 1: Stop if x and y are aleady adjacent
    if isAdjacent(g, x, y)
        return false
    end

    return true
end


"""
Insert validity (Chickering 2002, Theorem 15):
Insert(x, y, T) is valid in CPDAG G iff:
1. NAyxT is a clique 
2. Every undirected path between x and y is blocked by NAyxT.
"""
function isValidInsert(g, op::InsertOperator)

    (; x, y, T) = op

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
function isValidDelete(g, op::DeleteOperator)

    (; x, y, H, NAyx) = op

    #Not valid if there is no edge to delete
    if !isAdjacent(g, x, y)
        return false
    end

    #If NAyx \ H is a clique, then valid
    return isClique(g, setdiff(NAyx, H))
end