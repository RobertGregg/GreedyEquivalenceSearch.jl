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

#=
The notation from Chickering and Hauser are different and a bit confusing to translate. Hauser wants to re-orient the edge u←v to u→v. We translate this to re-orienting the edge x←y to x→y (so x=u and y=v). 

Next Hauser lets C ⊂ neighbors(g,v) and defines N as neighbors(g,v) ∩ adjacencies(g,u). The validity conditions then become:

    1. C is a clique
    2. N ⊂ C
    3. Every (semi-directed) path from v to u in G except u←v has a vertex in C ∪ neighbors(g,u)

In Chickering, T is defined as ⊂ neighbors(g,y) \ adjacencies(g,x) and NAyx as neighbors(g,y) ∩ adjacencies(g,x), so the validity checks are equivalent to:

    1. NAyx ∪ T is a clique
    2. Every (semi-directed) path from y to x in G except x←y has a vertex in NAyx ∪ T ∪ neighbors(g,x)

Finally, the last implicit check is that x←y exists which can be checked as y ∈ parents(g,x)
=#


"""
Turn validity (Hauser 2012, Proposition 34):
Change the directed edge x←y to x→y
Turn(x, y, T) is valid iff:
1. y ∈ Pa(x) 
2. NAyxT is a clique 
3. All semi-directed paths from y to x other than x←y are blocked by NAyxT ∪ Ne(x)
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