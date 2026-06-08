
####################################################################
# Main Function
####################################################################

#TODO add support for graph node labels

"""
    ges(data; verbose=false)
Compute a causal graph for the given observed data.
"""
function ges(data::AbstractMatrix; verbose=false, maxDegree=16)

    stats = SufficientStats(data)
    g = Graph(stats.variablesCount; maxDegree)

    forwardPhase!(g, stats; verbose)
    backwardPhase!(g, stats; verbose)

    return g
end

#Try to convert data to matrix (e.g., a DataFrame)
ges(data; verbose=false, maxDegree=16) = ges(Matrix(data); verbose, maxDegree)


# #executes when verbose flag is true
function printState(stage, op, cache)
    forward = stage == "Forward Search"

    subset = forward ?
        SmallVector{capacity(op.T)}(op.T) :
        SmallVector{capacity(op.H)}(op.H)

    cache_pct = round(100 * length(cache) / cache.capacity, digits=3)

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

    # PDAGtoDAG(g)
    # DAGtoCPDAG(g)

    return nothing
end


"""
    forwardSearch!(g, stats::SufficientStats)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function forwardPhase!(g, stats; verbose=false, nbuffers = Threads.nthreads())

    # #Cached score function for InsertOperator
    score = CachedScore(stats, Val(maxDegree(g)))

    #potential idea: save the "base" operator for each (x,y) and only update T,score,etc
    # operators = [InsertOperator(g, x, y) for (x,y) in allPermutationPairs(vertices(g))]

    # tmap!(operators, operators) do currentInsertOperator

    #     for op in insertCandidates(g, currentInsertOperator)
    #         if isValidInsert(g, op)

    #             #Calculate the change in score for applying this operator
    #             op = score(op)

    #             if op > currentInsertOperator
    #                 currentInsertOperator = op
    #             end
    #         end
    #     end

    #     currentInsertOperator
    # end

    
    #1. For each pair of nodes, generate all possible candidates
    #2. Test if candidate is valid
    #3. If valid score and check against best found operator
    #4. After iterating all nodes, insert the best candidate
    while true

        #TODO Use saved neighbors and parents of y to skip some validity checks
        bestInsertOperator = tmapreduce(max, PermutationPairs(nv(g))) do (x,y)

            currentInsertOperator = InsertOperator(g, x, y)
        
            for op in insertCandidates(g, currentInsertOperator)

                #precheckScore(op, score, currentInsertOperator) && continue

                isValidInsert(g, op) || continue
                    
                #Calculate the change in score for applying this operator
                op = score(op)
    
                if op > currentInsertOperator
                    currentInsertOperator = op
                end
        
            end
        
            return currentInsertOperator
        end
        
        #For profiling it's easier to optimize other parts of the code using the nonparallel loop
        # bestInsertOperator = InsertOperator(g, 1, 2)
        # for (x,y) in allPermutationPairs(vertices(g))

        #     currentInsertOperator = InsertOperator(g, x, y)
        #     for op in insertCandidates(g, currentInsertOperator)

        #         #Score "sparse" operators immediately and skip if low score
        #         precheckScore(op, score, bestInsertOperator) && continue

        #         #Check for adjacencies, cliques, and semi-directed paths
        #         isValidInsert(g, op) || continue

        #         #Calculate the change in score for applying this operator
        #         op = score(op)

        #         if op > bestInsertOperator
        #             bestInsertOperator = op
        #         end

        #     end
        # end


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



function insertCandidates(g, op)
    
    #neighbors of y that are not adjacent to x
    T = setdiff(op.neighborsY, adjacencies(g, op.x))
    
    return (setT(op,Tᵢ) for Tᵢ in powerset(T))
end


#It's faster to score operators with few neighbors than to check validity
function precheckScore(op, score, bestInsertOperator)

    (; T, NAyx) = op

    if length(NAyx ∪ T) ≤ 2
        op = score(op)

        if bestInsertOperator > op
            return true
        end
    end

    return false
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




"""
backwardPhase!(g, stats::SufficientStats)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function backwardPhase!(g, stats; verbose=false)
    
    #TODO resuse same cached score
    #Cached score function for DeleteOperator
    score = CachedScore(stats,  Val(maxDegree(g)))
    
    #1. For each pair of nodes, generate all possible candidates
    #2. Iterate candidates and test if they are valid
    #3. If valid score and check against best found operator
    #4. After iterating all nodes, insert the best candidate
    while true

        bestDeleteOperator = tmapreduce(max, PermutationPairs(nv(g))) do (x,y)
        
            currentDeleteOperator = DeleteOperator(g, x, y)
        
            for op in deleteCandidates(g, currentDeleteOperator)
                if isValidDelete(g, op)
        
                    op = score(op)
        
                    if op > currentDeleteOperator
                        currentDeleteOperator = op
                    end
        
                end
            end
        
            currentDeleteOperator
        end

        # bestDeleteOperator = DeleteOperator(g,1,2)
        # for (x,y) in allPermutationPairs(vertices(g))
        
        #     currentDeleteOperator = DeleteOperator(g, x, y)
        
        #     for op in deleteCandidates(g, currentDeleteOperator)
        #         if isValidDelete(g, op)
        
        #             op = score(op)
        
        #             if op > bestDeleteOperator
        #                 bestDeleteOperator = op
        #             end
        
        #         end
        #     end
        #     currentDeleteOperator
        # end

        
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



function deleteCandidates(g, op)
    

    #neighbors of y that are adjacent to x
    H = op.NAyx
    
    return (setH(op, Hᵢ) for Hᵢ in powerset(H))
end