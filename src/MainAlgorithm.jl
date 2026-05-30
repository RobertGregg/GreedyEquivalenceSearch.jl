
"""
    ges(data; verbose=false)
Compute a causal graph for the given observed data.
"""
function ges(data; verbose=false)
    
    #TODO Either tell the user to mean center data or have a check for this
    data .-= mean(data,dims=1)

    stats = SufficientStats(data)
    g = Graph(stats.variablesCount)

    forwardPhase!(g, stats; verbose)
    backwardPhase!(g, stats; verbose)

    return g
end

# #executes when verbose flag is true
function printState(stage, op, cache)
    forward = stage == "Forward Search"

    subset = forward ?
        SmallVector{capacity(op.T)}(op.T) :
        SmallVector{capacity(op.H)}(op.H)

    cache_pct = round(100 * length(cache) / cache.maxsize, digits=3)

    printstyled("[$stage]", color=forward ? :green : :red, bold=true)

    print(" ")

    printstyled("Edge=", color=:cyan, bold=true)
    print(op.x, "→", op.y)

    print(" ")

    printstyled("ΔScore=", color=:black, bold=true)
    print(round(op.scoreDelta, digits=4))

    print(" ")

    printstyled("Subset=", color=:magenta, bold=true)
    print(subset)

    print(" ")

    printstyled("Cache=", color=:blue, bold=true)
    println(cache_pct, "%")
end


####################################################################
# Forward Search Functions
####################################################################


"""
    Insert!(g, op::InsertOperator)
Modify the graph `g` by directing the edge `op.x`→`op.y` and orient all neighbors of `y` not connected to `x` toward `y`. Additionally use Meek rules to convert back to a CPDAG.
"""
function Insert!(g, op::InsertOperator) 

    (; x, y, T) = op

    #Add a directed edge x→y (currently no edge present)
    addEdge!(g, x, y)
    
    #Orient all edges incident into child node
    for t in T
        orientEdge!(g, t, y) #t→y
    end

    #Extend to CPDAG 
    graphVStructure!(g)
    meekRules!(g)

    return nothing
end


"""
    forwardSearch!(g, stats::SufficientStats)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function forwardPhase!(g, stats; verbose=false)
    
    #The first edge is always the pair of variables with the highest correlation = cov²(x,y)/(var(x)⋅var(y))
    # Σ = stats.covariance
    # x, y = argmax(((i,j),) -> Σ[i,j]^2 / (Σ[i,i] * Σ[j,j]), allCombinationPairs(vertices(g)))

    # bestInsertOperator = InsertOperator(g, x, y)
    # Insert!(g, bestInsertOperator)


    # #Cached score function for InsertOperator
    score = CachedScore(stats)

    # #Print first insert if verbose
    # verbose && printState("Forward Search", bestInsertOperator, score.cache)
    
    #1. For each pair of nodes, generate all possible candidates
    #2. Iterate candidates and test if they are valid
    #3. If valid score and check against best found operator
    #4. After iterating all nodes, insert the best candidate
    while true
        #TODO Save neighbors and parents of each node to skip some validity checks

        # bestInsertOperator = tmapreduce(max, PermutationPairs(nv(g))) do (x,y)
        
        #     currentInsertOperator = InsertOperator(g, x, y)
        
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
        
        # #For profiling it's easier to optimize other parts of the code using the nonparallel loop
        bestInsertOperator = InsertOperator(g, 1, 2)
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
    
    #neighbors of y that are not adjacent to x
    T = setdiff(neighborsY, adjacenciesX)
    
    return (InsertOperator(x, y, Tᵢ, neighborsY, adjacenciesX) for Tᵢ in powerset(T))
end


####################################################################
# Backward Search Functions
####################################################################


"""
Delete!(g, op::DeleteOperator)
Modify the graph `g` by removing the edge `op.x`→`op.y`. Additionally, orient all neighbors of `x` and `y` away from `x` and `y`.
"""
function Delete!(g, op::DeleteOperator)
    
    (; x, y, H) = op
    #remove directed and unidrected edges (x→y and x-y)
    removeEdge!(g, x, y)
    
    #Orient all vertices in H toward x and y
    for h in H
        orientEdge!(g, y, h) #y→h
        orientEdge!(g, x, h) #x→h
    end
    
    return nothing
end


function deleteCandidates(g,x,y)
    
    neighborsY = neighbors(g,y)
    adjacenciesX = adjacencies(g,x)

    #neighbors of y that are adjacent to x
    H = neighborsY ∩ adjacenciesX
    
    return (DeleteOperator(x, y, Hᵢ, neighborsY, adjacenciesX) for Hᵢ in powerset(H))
end




"""
backwardPhase!(g, stats::SufficientStats)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function backwardPhase!(g, stats; verbose=false)
    
    #TODO resuse same cached score
    #Cached score function for DeleteOperator
    score = CachedScore(stats)
    
    #1. For each pair of nodes, generate all possible candidates
    #2. Iterate candidates and test if they are valid
    #3. If valid score and check against best found operator
    #4. After iterating all nodes, insert the best candidate
    while true

        bestDeleteOperator = tmapreduce(max, PermutationPairs(nv(g))) do (x,y)
        
            currentDeleteOperator = DeleteOperator(g, x, y)
        
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

