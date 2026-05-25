
"""
    Insert!(g, op::InsertOperator)
Modify the graph `g` by directing the edge `op.x`→`op.y`. Additionally, orient all neighbors of `y` not connected to `x` toward `y`.
"""
function Insert!(g, op::InsertOperator) 

    #Add a directed edge x→y (currently no edge present)
    addEdge!(g, op.x, op.y)
    
    #Orient all edges incident into child node
    for t in op.T
        orientEdge!(g, t, op.y) #t→y
    end

    #Restore CPDAG 
    graphVStructure!(g)
    meekRules!(g)

    return nothing
end


"""
    forwardSearch!(g, state::CurrentState)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function forwardPhase(g, stats)
    

    #Create a Binary Heap to store valid, scored insert operators. We use a mutable verison to update valid inserts
    # validInserts = MutableBinaryMaxHeap{InsertOperator}()

    #This might be easier to use because it acts more like a dictionary, but still sorts. 
    validInserts = PriorityQueue{InsertOperator, Float64, DataStructures.FasterReverse}(
           DataStructures.FasterReverse()
       )

    #The first edge is always the pair of variables with the highest covariance 
    x, y = argmax(((i,j),) -> stats.covariance[i,j], allPairs(vertices(g)))
    ∅ = SmallSet{maxDegree(g),Int}()

    bestInsertOperator = InsertOperator(x, y, ∅)
    Insert!(g, bestInsertOperator)
    
    while true
        
        for (x,y) in allPairs(vertices(g))
            
            # (bestInsertOperator, bestScore) = popfirst!(validInserts)
        end

    end
end


function candidates(g,x,y)
    
    #neighbors of y that are adjacent to x
    NAyx = neighbors(g,y) ∩ adjacencies(g,x)
    
    #neighbors of y that are not adjacent to x
    T = setdiff(neighbors(g,y), adjacencies(g,x))


    return (InsertOperator(x, y, NAyx ∪ Tᵢ, 0.0) for Tᵢ in powerset(T))
end


