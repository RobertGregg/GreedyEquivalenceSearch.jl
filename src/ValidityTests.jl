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

    (; x, y, C) = op

    #If x and y are not adjacent, then invalid
    isAdjacent(g, x, y) || return false

    NAyx = neighbors(g,y) ∩ adjacencies(g,x)
    #If NAyx \ H is a clique, then valid
    return isClique(g, setdiff(NAyx, H))
end


function isValid(g, op::InsertOperator)

    (; x, y, T, E) = op

    #I1
    if isAdjacent(g, x, y)
        return false
    end

    #I2
    if !issubset(T, setdiff(neighbors(g, y), adjacencies(g, x)))
        return false
    end

    #I3
    NAyxT = neighbors(g, y) ∩ adjacencies(g, x) ∪ T
    if !isClique(g, NAyxT)
        return false
    end

    #I5
    if E ≠ (NAyxT ∪ parents(g, y))
        return false
    end

    #I4 (tested last b/c computationally intensive)
    if !isBlocked(g, x, y, NAyxT)
        return false
    end

    return true
end



function isValid(g, op::DeleteOperator)

    # println("Test $op")
    (; x, y, C, E) = op

    #D1
    if !isAdjacent(g, x, y)
        # println("$x and $y are not adjacent, no edge to delete")
        return false
    end


    #D2
    if !issubset(C, neighbors(g, y) ∩ adjacencies(g, x))
        # println("C=$(collect(C)) is no longer a subset of NAyx=$(collect(neighbors(g, y) ∩ adjacencies(g, x)))")
        return false
    end

    #D4
    if E ≠ (C ∪ parents(g, y))
        # println("E=$(collect(E)) is no longer valid C ∪ Pay=$(collect(C ∪ parents(g, y)))")
        return false
    end

    #D3
    if !isClique(g, C)
        # println("C=$(collect(C)) is not a clique")
        return false
    end

    return true
end



####################################################################
#  Edge Updates
####################################################################

# Nazaret, A. & Blei, D. Extremely Greedy Equivalence Search.

# Define an explicit Enum for the 7 structural transitions
@enum EdgeUpdate begin
    U1_NONE_TO_UNDIRECTED      # a  b  ->  a - b   addUndirectedEdge!(g, a, b)
    U2_NONE_TO_DIRECTED        # a  b  ->  a → b   addDirectedEdge!(g, a, b)
    U3_UNDIRECTED_TO_NONE      # a - b ->  a  b    removeUndirectedEdge!(g, a, b)
    U4_UNDIRECTED_TO_DIRECTED  # a - b ->  a → b   orientEdge!(g, a, b)
    U5_DIRECTED_TO_NONE        # a → b ->  a  b    removeDirectedEdge!(g, a, b)
    U6_DIRECTED_TO_UNDIRECTED  # a → b ->  a - b   unorientEdge!(g, a, b)
    U7_REVERSED_DIRECTION      # a → b ->  a ← b
end

function addInsertCandidates(g, a, b, operatorSet, score, update::EdgeUpdate)

    if update == U1_NONE_TO_UNDIRECTED
        # Table 5: y ∈ {a, b} OR y ∈ Ne(a) ∩ Ne(b) OR (x=a AND y ∈ Ne(b)) OR (x=b AND y ∈ Ne(a))
        # 1. y ∈ {a, b}
        for x in vertices(g)
            x ≠ a && pushInserts(g, x, a, operatorSet, score)
            x ≠ a && pushInserts(g, x, b, operatorSet, score)
        end
        # 2. y ∈ Ne(a) ∩ Ne(b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in vertices(g), y in sharedNeighbors
            x ∈ (a, b, y) || pushInserts(g, x, y, operatorSet, score)
        end
        # 3. x=a AND y ∈ Ne(b)
        for y in neighbors(g, b)
            pushInserts(g, a, y, operatorSet, score)
        end
        # 4. x=b AND y ∈ Ne(a)
        for y in neighbors(g, a)
            pushInserts(g, b, y, operatorSet, score)
        end

    elseif update == U2_NONE_TO_DIRECTED
        # Table 5: y=b OR y ∈ Ne(a) ∩ Ne(b) OR (x=a AND y ∈ Ne(b)) OR (x=b AND y ∈ Ne(a))
        # 1. y=b
        for x in vertices(g)
            x ≠ b && pushInserts(g, x, b, operatorSet, score)
        end
        # 2. y ∈ Ne(a) ∩ Ne(b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in vertices(g), y in sharedNeighbors
            x ∈ (a, b, y) || pushInserts(g, x, y, operatorSet, score)
        end
        # 3. x=a AND y ∈ Ne(b)
        for y in neighbors(g, b)
            pushInserts(g, a, y, operatorSet, score)
        end
        # 4. x=b AND y ∈ Ne(a)
        for y in neighbors(g, a)
            pushInserts(g, b, y, operatorSet, score)
        end

    elseif update == U3_UNDIRECTED_TO_NONE
        # Table 5: (x=a AND y ∈ Ne(b) ∪ b) OR (x=b AND y ∈ Ne(a) ∪ a) OR (y=a AND x ∈ Ad(b)) OR ...
        # (y=b AND x ∈ Ad(a)) OR SD(x,y;a,b) OR SD(x,y;a,b)
        # 1. x=a AND y ∈ Ne(b) ∪ b
        bNeighbors = push(neighbors(g, b), b)
        for y in bNeighbors
            pushInserts(g, a, y, operatorSet, score)
        end
        # 2. x=b AND y ∈ Ne(a) ∪ a
        aNeighbors = push(neighbors(g, a), a)
        for y in aNeighbors
            pushInserts(g, b, y, operatorSet, score)
        end
        # 3. y=a AND x ∈ Ad(b)
        for x in adjacencies(g, b)
            pushInserts(g, x, a, operatorSet, score)
        end
        # 4. y=b AND x ∈ Ad(a)
        for x in adjacencies(g, a)
            pushInserts(g, x, b, operatorSet, score)
        end

    elseif update == U4_UNDIRECTED_TO_DIRECTED
        # Table 5: (y=a AND x ∈ Ad(b)) OR y=b OR SD(x,y;b,a)
        # 1. y=a AND x ∈ Ad(b)
        for x in adjacencies(g, b)
            pushInserts(g, x, a, operatorSet, score)
        end
        # 2. y=b
        for x in vertices(g)
            x ≠ b && pushInserts(g, x, b, operatorSet, score)
        end
    elseif update == U5_DIRECTED_TO_NONE
        # Table 5: y=b OR (x=a AND y ∈ Ne(b) ∪ b) OR (x=b AND y ∈ Ne(a) ∪ a) OR SD(x,y;a,b)
        # 1. y=b
        for x in vertices(g)
            x ≠ b && pushInserts(g, x, b, operatorSet, score)
        end
        # 2. x=a AND y ∈ Ne(b) ∪ b
        bNeighbors = push(neighbors(g, b), b)
        for y in bNeighbors
            pushInserts(g, a, y, operatorSet, score)
        end
        # 3. x=b AND y ∈ Ne(a) ∪ a
        aNeighbors = push(neighbors(g, a), a)
        for y in aNeighbors
            pushInserts(g, b, y, operatorSet, score)
        end
    elseif update == U6_DIRECTED_TO_UNDIRECTED
        # Table 5: y ∈ {a, b}
        # Target 'y' must be either 'a' or 'b'.
        for x in vertices(g)
            x ≠ a && pushInserts(g, x, a, operatorSet, score)
            x ≠ b && pushInserts(g, x, b, operatorSet, score)
        end
    elseif update == U7_REVERSED_DIRECTION
        # Table 5: y ∈ {a, b} OR SD(x,y;a,b)
        # Target 'y' must be either 'a' or 'b'.
        for x in vertices(g)
            x ≠ a && pushInserts(g, x, a, operatorSet, score)
            x ≠ b && pushInserts(g, x, b, operatorSet, score)
        end
    end

    return nothing
end




function addDeleteCandidates(g, a, b, operatorSet, score, update::EdgeUpdate)

    if update == U3_UNDIRECTED_TO_NONE
        # Table 5: ∅ 
        # Instantly exit. Deleting an undirected edge yields zero new deletes.
        return nothing

    elseif update == U4_UNDIRECTED_TO_DIRECTED || update == U5_DIRECTED_TO_NONE
        # Table 5: y = b
        # Target 'y' must be 'b'. 'x' can be any other node.
        for x in vertices(g)
            x ≠ b && pushDeletes(g, x, b, operatorSet, score)
        end


    elseif update == U6_DIRECTED_TO_UNDIRECTED || update == U7_REVERSED_DIRECTION
        # Table 5: y ∈ {a, b}
        # Target 'y' must be either 'a' or 'b'.
        for x in vertices(g)
            x ≠ a && pushDeletes(g, x, a, operatorSet, score)
            x ≠ b && pushDeletes(g, x, b, operatorSet, score)
        end

    elseif update == U1_NONE_TO_UNDIRECTED
        # Table 5: y ∈ {a, b} OR x ∈ {a, b} OR (x ∈ Ad(a) ∩ Ad(b) AND y ∈ Ne(a) ∩ Ne(b))

        # 1. y ∈ {a, b}
        for x in vertices(g)
            x ≠ a && pushDeletes(g, x, a, operatorSet, score)
            x ≠ b && pushDeletes(g, x, b, operatorSet, score)
        end
        # 2. x ∈ {a, b}
        for y in vertices(g)
            y ≠ a && pushDeletes(g, a, y, operatorSet, score)
            y ≠ b && pushDeletes(g, b, y, operatorSet, score)
        end
        # 3. Intersections
        sharedAdjacencies = adjacencies(g, a) ∩ adjacencies(g, b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in sharedAdjacencies, y in sharedNeighbors
            x ≠ y && pushDeletes(g, x, y, operatorSet, score)
        end

    elseif update == U2_NONE_TO_DIRECTED
        # Table 5: y = b OR x ∈ {a, b} OR (x ∈ Ad(a)∩Ad(b) AND y ∈ Ne(a)∩Ne(b))

        # 1. y = b
        for x in vertices(g)
            x ≠ b && pushDeletes(g, x, b, operatorSet, score)

        end
        # 2. x ∈ {a, b}
        for y in vertices(g)
            y ≠ a && pushDeletes(g, a, y, operatorSet, score)
            y ≠ b && pushDeletes(g, b, y, operatorSet, score)

        end
        # 3. Intersections
        sharedAdjacencies = adjacencies(g, a) ∩ adjacencies(g, b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in sharedAdjacencies, y in sharedNeighbors
            x ≠ y && pushDeletes(g, x, y, operatorSet, score)
        end
    end

    return nothing
end


function addAllCandidates(g, x, y, operatorSet, score, update::EdgeUpdate)

    addInsertCandidates(g, x, y, operatorSet, score, update)
    addDeleteCandidates(g, x, y, operatorSet, score, update)

    return nothing
end

addAllCandidates(g, edge::GraphEdge, operatorSet, score, update::EdgeUpdate) = addAllCandidates(g, edge.parent, edge.child, operatorSet, score, update)



function pushInserts(g, x, y, operatorSet, score)

    for T in powerset(neighbors(g, y) ∩ adjacencies(g, x))
        op = InsertOperator(g, x, y, T, score)
        op.scoreDelta > 0 && push!(operatorSet, op)
    end

    return nothing
end

function pushDeletes(g, x, y, operatorSet, score)

    for C in powerset( neighbors(g, y) ∩ adjacencies(g, x))
        op = DeleteOperator(g, x, y, C, score)
        if op.scoreDelta > 0
            push!(operatorSet, op)
        else
            println("Ignored $op because Δscore was less than zero")
        end
    end

    return nothing
end