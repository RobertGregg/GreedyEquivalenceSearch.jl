
"""
    Insert!(g, op::InsertOperator)
Modify the graph `g` by directing the edge `op.x`→`op.y` and orient all neighbors of `y` not connected to `x` toward `y`. Additionally use Meek rules to convert back to a CPDAG
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
function forwardPhase(g, stats; verbose=false)
    
    #The first edge is always the pair of variables with the highest covariance 
    x, y = argmax(((i,j),) -> stats.covariance[i,j], allCombinationPairs(vertices(g)))
    ∅ = SmallSet{maxDegree(g), Int}()

    bestInsertOperator = InsertOperator(x, y, ∅)
    Insert!(g, bestInsertOperator)


    #Cached score function for InsertOperator
    score = CachedScore(stats)
    
    #1. For each pair of nodes, generate all possible candidates
    #2. Iterate candidates and test if they are valid
    #3. If valid score and store in PriorityQueue
    #4. After iterating all nodes, insert the best candidate
    while true
        #TODO Save neighbors and parents of each node to skip some validity checks

        bestInsertOperator = tmapreduce(max, PermutationPairs(nv(g))) do (x,y)

            currentInsertOperator = InsertOperator(x, y, ∅)

            for op in candidates(g,x,y)
                if isValidInsert(g, op)

                    scoredOperator = score(g, op)

                    if scoredOperator > currentInsertOperator
                        currentInsertOperator = scoredOperator
                    end

                end
            end

            currentInsertOperator
        end

        
        if bestInsertOperator.scoreDelta > 0
            Insert!(g, bestInsertOperator)
        else
            break
        end
        
        if verbose
            printState("Forward Search", bestInsertOperator, score.cache)
        end
    end

    return g
end


function printState(stage, op, cache)

    printstyled("Current State\n", bold=true, color=:blue)
    print("Stage: ")
    printstyled("$stage\n", color= stage == "Forward Search" ? :green : :red)
    println("Score: $(op.scoreDelta)")
    println("Edge: $(op.x)→$(op.y)")
    println("Subset: $(op.T)")
    println("Cache: $(round(100length(cache) / cache.maxsize, digits=3))%")
    println("----------------------------------")
end 

function candidates(g,x,y)
    
    #neighbors of y that are adjacent to x
    NAyx = neighbors(g,y) ∩ adjacencies(g,x)
    
    #neighbors of y that are not adjacent to x
    T = setdiff(neighbors(g,y), adjacencies(g,x))

    return (InsertOperator(x, y, NAyx ∪ Tᵢ) for Tᵢ in powerset(T))
end