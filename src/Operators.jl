####################################################################
#  Operator structs + validity checks
####################################################################


struct InsertOp{S<:AbstractSmallSet}
    x::Int
    y::Int
    T::S   # subset of Ne(y) \ Ad(x)
    score_delta::Float64
end

struct DeleteOp{S<:AbstractSmallSet}
    x::Int
    y::Int
    H::S   # subset of Ne(y) ∩ Ad(x)
    score_delta::Float64
end

#Used to compare operators for binary heap
Base.isless(a::InsertOp, b::InsertOp) = a.score_delta < b.score_delta
Base.isless(a::DeleteOp, b::DeleteOp) = a.score_delta < b.score_delta



"""
Insert validity (Chickering 2002, Theorem 15):
Insert(x, y, T) is valid in CPDAG G iff:
1. x and y are not adjacent.
2. T ⊆ Ne(y) \\ Ad(x)
3. NAyxT is a clique in G
4. Every undirected path between x and y is blocked by NAyxT.
"""
function isValidInsert(g, x, y, T)
    
    #If x and y are adjacent then invalid
    isAdjacent(g, x, y) && return false

    Ny = neighbors(g,y)
    Ax = adjacencies(g, x)
    
    #T is a subset of Ne(y) \\ Ad(x)
    T ⊆ setdiff(Ny, Ax) || return false
    
    #(neighbors of y and adjacent to x) or in T
    NAyxT = Ny ∩ Ax ∪ T

    #If T not a clique, then invalid
    isClique(g, NAyxT) || return false
    
    #If blocking, then valid
    return isBlocked(g, x, y, NAyxT)
end

isValidInsert(g, op::InsertOp) = isValidInsert(g, op.x, op.y, op.T)

"""
Delete validity (Chickering 2002, Theorem 17):
Delete(x, y, H) is valid iff:
1. x and y are adjacent.
2. H ⊆ Ne(y) ∩ Ad(x)
3. H is a clique.
"""
function isValidDelete(g, x, y, H)
    
    #If x and y are not adjacent, then invalid
    isAdjacent(g, x, y) || return false
    
    # H is a subset of Ne(y) ∩ Ad(x)
    NAyx = neighbors(g,y) ∩ adjacencies(g, x) 
    H ⊆ NAyx || return false
    
    #If NAyx \ H is a clique, then valid
    return isClique(g, setdiff(NAyx, H))
end

isValidInsert(g, op::DeleteOp) = isValidInsert(g, op.x, op.y, op.H)