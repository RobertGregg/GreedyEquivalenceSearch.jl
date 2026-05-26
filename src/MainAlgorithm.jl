
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
    
    #The first edge is always the pair of variables with the highest covariance 
    x, y = argmax(((i,j),) -> stats.covariance[i,j], allCombinationPairs(vertices(g)))
    ∅ = SmallSet{maxDegree(g)}()

    bestInsertOperator = InsertOperator(x, y, ∅)
    Insert!(g, bestInsertOperator)


    #TODO Use PriorityQueue to cache scores or a separate LRU?
    #This might be easier to use because it acts more like a dictionary, but still sorts. 
    validInserts = PriorityQueue{InsertOperator{typeof(∅)}, Float64, DataStructures.FasterReverse}(
           DataStructures.FasterReverse()
       )

    
    #1. For each pair of nodes, generate all possible candidates
    #2. Iterate candidates and test if they are valid
    #3. If valid score and store in PriorityQueue
    #4. After iterating all nodes, insert the best candidate
    while true
        
        for (x,y) in allPermutationPairs(vertices(g))
            
            for op in candidates(g,x,y)
                if isValidInsert(g, op)
                    deltaScore = score(stats, y, op.T ∪ parents(g,y) ∪ x) - score(stats, y, op.T ∪ parents(g,y))
                    validInserts[op] = deltaScore
                elseif haskey(validInserts,op)
                    delete!(validInserts, op)
                end
            end
        end
            
        (bestInsertOperator, bestScore) = popfirst!(validInserts)

        if bestScore > 0
            Insert!(g, bestInsertOperator)
        else
            break
        end

        printState("Forward Search", bestScore, bestInsertOperator, validInserts)
    end

    return g
end


function printState(stage, score, op, pq)

    printstyled("Current State\n", bold=true, color=:blue)
    print("Stage: ")
    printstyled("$stage\n", color= stage == "Forward Search" ? :green : :red)
    println("Score: $score")
    println("Edge: $(op.x)→$(op.y)")
    println("Subset: $(op.T)")
    println("Cache: $(length(pq))")
    println("----------------------------------")
end 

function candidates(g,x,y)
    
    #neighbors of y that are adjacent to x
    NAyx = neighbors(g,y) ∩ adjacencies(g,x)
    
    #neighbors of y that are not adjacent to x
    T = setdiff(neighbors(g,y), adjacencies(g,x))


    return (InsertOperator(x, y, NAyx ∪ Tᵢ) for Tᵢ in powerset(T))
end


