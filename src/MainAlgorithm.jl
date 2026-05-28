
"""
    ges(data; verbose=false)
Compute a causal graph for the given observed data.
"""
function ges(data; verbose=false)
    
    stats = SufficientStats(data)
    g = Graph(stats.variablesCount)

    forwardPhase!(g, stats; verbose)
    backwardPhase!(g, stats; verbose)

    return g
end

#executes when verbose flag is true
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

####################################################################
# Forward Search Functions
####################################################################


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

    #Extend to CPDAG 
    graphVStructure!(g)
    meekRules!(g)

    return nothing
end


"""
    forwardSearch!(g, state::CurrentState)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function forwardPhase!(g, stats; verbose=false)
    
    #The first edge is always the pair of variables with the highest covariance 
    x, y = argmax(((i,j),) -> stats.covariance[i,j], allCombinationPairs(vertices(g)))
    ∅ = SmallSet{maxDegree(g), Int}()

    bestInsertOperator = InsertOperator(x, y, ∅)
    Insert!(g, bestInsertOperator)


    #Cached score function for InsertOperator
    score = CachedScore(stats)
    
    #1. For each pair of nodes, generate all possible candidates
    #2. Iterate candidates and test if they are valid
    #3. If valid score and check against best found operator
    #4. After iterating all nodes, insert the best candidate
    while true
        #TODO Save neighbors and parents of each node to skip some validity checks

        # bestInsertOperator = tmapreduce(max, PermutationPairs(nv(g))) do (x,y)
        
        #     currentInsertOperator = InsertOperator(x, y, ∅)
        
        #     for op in insertCandidates(g,x,y)
        #         if isValidInsert(g, op)
        
        #             scoredOperator = score(g, op)
        
        #             if scoredOperator > currentInsertOperator
        #                 currentInsertOperator = scoredOperator
        #             end
        
        #         end
        #     end
        
        #     currentInsertOperator
        # end
        
        #For profiling it's easier to optimize other parts of the code using the nonparallel loop
        bestInsertOperator = InsertOperator(x, y, ∅)
        for (x,y) in allPermutationPairs(vertices(g))

            for op in insertCandidates(g,x,y)

                #Check for adjacencies, cliques, and semi-directed paths
                if isValidInsert(g, op)

                    scoredOperator = score(g, op)

                    if scoredOperator > bestInsertOperator
                        bestInsertOperator = scoredOperator
                    end

                end
            end
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

    return nothing
end




function insertCandidates(g,x,y)
    
    neighborsY = neighbors(g,y)
    adjacenciesX = adjacencies(g,x)
    
    #neighbors of y that are adjacent to x
    NAyx = neighborsY ∩ adjacenciesX
    
    #neighbors of y that are not adjacent to x
    T = setdiff(neighborsY, adjacenciesX)

    return (InsertOperator(x, y, NAyx ∪ Tᵢ) for Tᵢ in powerset(T))
end


####################################################################
# Backward Search Functions
####################################################################


"""
    Delete!(g, state::CurrentState)
Modify the graph `g` by removing the edge `state.x`→`state.y`. Additionally, orient all neighbors of `x` and `y` away from `x` and `y`.
"""
function Delete!(g, op::DeleteOperator)

    #remove directed and unidrected edges (x→y and x-y)
    removeEdge!(g, op.x, op.y)
    
    #Orient all vertices in H toward x and y
    for h in op.H
        orientEdge!(g, y, h) #y→h
        orientEdge!(g, x, h) #x→h
    end

    return nothing
end


function deleteCandidates(g,x,y)
    

    #neighbors of y that are adjacent to x
    H = neighbors(g,y) ∩ adjacencies(g,x)

    return (DeleteOperator(x, y, Hᵢ) for Hᵢ in powerset(H))
end




"""
    forwardSearch!(g, state::CurrentState)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function backwardPhase!(g, stats; verbose=false)
    
    #TODO resuse same cached score
    #Cached score function for DeleteOperator
    score = CachedScore(stats)

    #TODO Define (Insert/Delete)Operator(x,y) with empty set as default?
    ∅ = SmallSet{maxDegree(g), Int}()
    
    #1. For each pair of nodes, generate all possible candidates
    #2. Iterate candidates and test if they are valid
    #3. If valid score and check against best found operator
    #4. After iterating all nodes, insert the best candidate
    while true

        bestDeleteOperator = tmapreduce(max, PermutationPairs(nv(g))) do (x,y)
        
            currentDeleteOperator = DeleteOperator(x, y, ∅)
        
            for op in deleteCandidates(g,x,y)
                if isValidDelete(g, op)
        
                    scoredOperator = score(g, op)
        
                    if scoredOperator > currentDeleteOperator
                        currentDeleteOperator = scoredOperator
                    end
        
                end
            end
        
            currentDeleteOperator
        end

        
        if bestDeleteOperator.scoreDelta > 0
            Delete!(g, bestDeleteOperator)
        else
            break
        end
        
        if verbose
            printState("Backward Search", bestDeleteOperator, score.cache)
        end
    end

    return nothing
end

