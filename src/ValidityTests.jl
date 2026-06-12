
#These checks are independent of T and can happen outside of the powerset loop
function precheckValidInsert(g, op::InsertOperator)
    
    (; x, y) = op

    #Check 1: Stop if x and y are aleady adjacent
    if isAdjacent(g,x,y)
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

    #If x and y are not adjacent, then invalid
    isAdjacent(g, x, y) || return false
    
    #If NAyx \ H is a clique, then valid
    return isClique(g, setdiff(NAyx, H))
end



####################################################################
#  Edge Updates
####################################################################

# Nazaret, A. & Blei, D. Extremely Greedy Equivalence Search.

# Define an explicit Enum for the 7 structural transitions
@enum EdgeUpdate begin
    U1_NONE_TO_UNDIRECTED      # a  b  ->  a - b
    U2_NONE_TO_DIRECTED        # a  b  ->  a → b
    U3_UNDIRECTED_TO_NONE      # a - b ->  a  b
    U4_UNDIRECTED_TO_DIRECTED  # a - b ->  a → b
    U5_DIRECTED_TO_NONE        # a → b ->  a  b
    U6_DIRECTED_TO_UNDIRECTED  # a → b ->  a - b
    U7_REVERSED_DIRECTION      # a → b ->  a ← b
end

function get_insert_candidates(g, a, b, update::EdgeUpdate)
    candidates = Set{Tuple{Int, Int}}()

    if update == U1_NONE_TO_UNDIRECTED
        # Table 5: y ∈ {a, b} OR y ∈ Ne(a) ∩ Ne(b) OR (x=a AND y ∈ Ne(b)) OR (x=b AND y ∈ Ne(a))
        # 1. y ∈ {a, b}
        for x in vertices(g)
            x ≠ a && push!(candidates, (x, a))
            x ≠ b && push!(candidates, (x, b))
        end
        # 2. y ∈ Ne(a) ∩ Ne(b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in vertices(g), y in sharedNeighbors
            x ≠ a && x ≠ b && push!(candidates, (x, y))
        end
        # 3. x=a AND y ∈ Ne(b)
        for y in neighbors(g, b)
            push!(candidates, (a, y))
        end
        # 4. x=b AND y ∈ Ne(a)
        for y in neighbors(g, a)
            push!(candidates, (b, y))
        end

    elseif update == U2_NONE_TO_DIRECTED
        # Table 5: y=b OR y ∈ Ne(a) ∩ Ne(b) OR (x=a AND y ∈ Ne(b)) OR (x=b AND y ∈ Ne(a))
        # 1. y=b
        for x in vertices(g)
            x ≠ b && push!(candidates, (x, b))
        end
        # 2. y ∈ Ne(a) ∩ Ne(b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in vertices(g), y in sharedNeighbors
            x ≠ a && x ≠ b && push!(candidates, (x, y))
        end
        # 3. x=a AND y ∈ Ne(b)
        for y in neighbors(g, b)
            push!(candidates, (a, y))
        end
        # 4. x=b AND y ∈ Ne(a)
        for y in neighbors(g, a)
            push!(candidates, (b, y))
        end

    elseif update == U3_UNDIRECTED_TO_NONE
        # Table 5: (x=a AND y ∈ Ne(b) ∪ b) OR (x=b AND y ∈ Ne(a) ∪ a) OR (y=a AND x ∈ Ad(b)) OR ...
        # (y=b AND x ∈ Ad(a)) OR SD(x,y;a,b) OR SD(x,y;a,b)
        # 1. x=a AND y ∈ Ne(b) ∪ b
        bNeighbors = push(neighbors(g, b), b)
        for y in bNeighbors
            push!(candidates, (a, y))
        end
        # 2. x=b AND y ∈ Ne(a) ∪ a
        aNeighbors = push(neighbors(g, a), a)
        for y in aNeighbors
            push!(candidates, (b, y))
        end
        # 3. y=a AND x ∈ Ad(b)
        for x in adjacencies(g, b)
            push!(candidates, (x, a))
        end
        # 4. y=b AND x ∈ Ad(a)
        for x in adjacencies(g, a)
            push!(candidates, (x, b))
        end
        
    elseif update == U4_UNDIRECTED_TO_DIRECTED
        # Table 5: (y=a AND x ∈ Ad(b)) OR y=b OR SD(x,y;b,a)
        # 1. y=a AND x ∈ Ad(b)
        for x in adjacencies(g, b)
            push!(candidates, (x, a))
        end
        # 2. y=b
        for x in vertices(g)
            x ≠ b && push!(candidates, (x, b))
        end
    elseif update == U5_DIRECTED_TO_NONE
        # Table 5: y=b OR (x=a AND y ∈ Ne(b) ∪ b) OR (x=b AND y ∈ Ne(a) ∪ a) OR SD(x,y;a,b)
        # 1. y=b
        for x in vertices(g)
            x ≠ b && push!(candidates, (x, b))
        end
        # 2. x=a AND y ∈ Ne(b) ∪ b
        bNeighbors = push(neighbors(g, b), b)
        for y in bNeighbors
            push!(candidates, (a, y))
        end
        # 3. x=b AND y ∈ Ne(a) ∪ a
        aNeighbors = push(neighbors(g, a), a)
        for y in aNeighbors
            push!(candidates, (b, y))
        end
    elseif update == U6_DIRECTED_TO_UNDIRECTED
        # Table 5: y ∈ {a, b}
        # Target 'y' must be either 'a' or 'b'.
        for x in vertices(g)
            x ≠ a && push!(candidates, (x, a))
            x ≠ b && push!(candidates, (x, b))
        end
    elseif update == U7_REVERSED_DIRECTION
        # Table 5: y ∈ {a, b} OR SD(x,y;a,b)
        # Target 'y' must be either 'a' or 'b'.
        for x in vertices(g)
            x ≠ a && push!(candidates, (x, a))
            x ≠ b && push!(candidates, (x, b))
        end
    end
    
    return candidates
end





function get_delete_candidates(g, a, b, update::EdgeUpdate)
    candidates = Set{Tuple{Int, Int}}()

    if update == U3_UNDIRECTED_TO_NONE
        # Table 5: ∅ 
        # Instantly exit. Deleting an undirected edge yields zero new deletes.
        return candidates

    elseif update == U4_UNDIRECTED_TO_DIRECTED || update == U5_DIRECTED_TO_NONE
        # Table 5: y = b
        # Target 'y' must be 'b'. 'x' can be any other node.
        for x in vertices(g)
            x ≠ b && push!(candidates, (x, b))
        end

    elseif update == U6_DIRECTED_TO_UNDIRECTED || update == U7_REVERSED_DIRECTION
        # Table 5: y ∈ {a, b}
        # Target 'y' must be either 'a' or 'b'.
        for x in vertices(g)
            x ≠ a && push!(candidates, (x, a))
            x ≠ b && push!(candidates, (x, b))
        end

    elseif update == U1_NONE_TO_UNDIRECTED
        # Table 5: y ∈ {a, b} OR x ∈ {a, b} OR (x ∈ Ad(a) ∩ Ad(b) AND y ∈ Ne(a) ∩ Ne(b))
        
        # 1. y ∈ {a, b}
        for x in vertices(g)
            x ≠ a && push!(candidates, (x, a))
            x ≠ b && push!(candidates, (x, b))
        end
        # 2. x ∈ {a, b}
        for y in vertices(g)
            y ≠ a && push!(candidates, (a, y))
            y ≠ b && push!(candidates, (b, y))
        end
        # 3. Intersections
        sharedAdjacencies = adjacencies(g, a) ∩ adjacencies(g, b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in sharedAdjacencies, y in sharedNeighbors
            x ≠ y && push!(candidates, (x, y))
        end

    elseif update == U2_NONE_TO_DIRECTED
        # Table 5: y = b OR x ∈ {a, b} OR (x ∈ Ad(a)∩Ad(b) AND y ∈ Ne(a)∩Ne(b))
        
        # 1. y = b
        for x in vertices(g)
            x ≠ b && push!(candidates, (x, b))
        end
        # 2. x ∈ {a, b}
        for y in vertices(g)
            y ≠ a && push!(candidates, (a, y))
            y ≠ b && push!(candidates, (b, y))
        end
        # 3. Intersections
        sharedAdjacencies = adjacencies(g, a) ∩ adjacencies(g, b)
        sharedNeighbors = neighbors(g, a) ∩ neighbors(g, b)
        for x in sharedAdjacencies, y in sharedNeighbors
            x ≠ y && push!(candidates, (x, y))
        end
    end

    return candidates
end