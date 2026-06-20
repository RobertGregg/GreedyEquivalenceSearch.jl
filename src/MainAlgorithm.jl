
####################################################################
# Main Function
####################################################################

#TODO add support for graph node labels

"""
    ges(data; verbose=false)
Compute a causal graph for the given observed data.
"""
function ges(data::AbstractMatrix; verbose=false, maxDegree=16, penalty=1.0)

    stats = SufficientStats(data; penalty)
    g = Graph(stats.variablesCount; maxDegree)

    forwardPhase!(g, stats; verbose)
    backwardPhase!(g, stats; verbose)

    return g
end



# executes when verbose flag is true
function printState(stage, op, cache)
    # Helper function for consistent styled printing
    function printfield(label, value, color)
        printstyled(label, color=color, bold=true)
        print(value, " ")
    end

    # Extract and compute underlying data
    forward = (stage == "Forward Search")
    subset  = forward ? collect(op.T) : collect(op.H)
    cache_pct = round(100 * length(cache) / cache.capacity, digits=3)

    printfield("[$stage]", "", forward ? :green : :red)
    printfield("Edge=", "$(op.x)→$(op.y)", :cyan)
    printfield("ΔScore=", round(op.scoreDelta, digits=4), :black)
    printfield("Subset=", subset, :magenta)
    

    printstyled("Cache=", color=:blue, bold=true)
    println(cache_pct, "%")
end

####################################################################
# Forward Search
####################################################################


"""
    forwardSearch!(g, stats::SufficientStats)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function forwardPhase!(g, stats; verbose=false)

    # #Cached score function for InsertOperator
    score = CachedScore(stats, eltype(g.parents))

    ops = [InsertOperator(g, x, y) for x in vertices(g), y in vertices(g) if x ≠ y]


    #1. For each pair of nodes, generate all possible candidates
    #2. Test if candidate is valid
    #3. If valid score and check against best found operator
    #4. After iterating all nodes, insert the best candidate
    while true

        #TODO Use saved neighbors and parents of y to skip some validity checks
        bestInsertOperator = tmapreduce(max, ops) do currentInsertOperator

            precheckValidInsert(g, currentInsertOperator) || return currentInsertOperator
    
            for op in insertCandidates(g, currentInsertOperator)
                isValidInsert(g, op) || continue
                op = score(op)
                op > currentInsertOperator && (currentInsertOperator = op)
            end
    
            return currentInsertOperator
        end



        if bestInsertOperator.scoreDelta > 0
            verbose && printState("Forward Search", bestInsertOperator, score.cache)
            Insert!(g, bestInsertOperator; verbose)
        else
            break
        end

    end

    return nothing
end



function insertCandidates(g, op)

    (; x, y) = op

    #neighbors of y that are not adjacent to x
    T = setdiff(neighbors(g, y), adjacencies(g, x))

    return (setT(op, Tᵢ) for Tᵢ in powerset(T))
end

####################################################################
# Backward Search Functions
####################################################################



"""
backwardPhase!(g, stats::SufficientStats)

Search equivance class space and continually add edges to `g` until the score stops increasing
"""
function backwardPhase!(g, stats; verbose=false)

    #TODO resuse same cached score
    #Cached score function for DeleteOperator
    score = CachedScore(stats, eltype(g.parents))
    
    ops = [DeleteOperator(g, x, y) for x in vertices(g), y in vertices(g) if x ≠ y]


    while true

        bestDeleteOperator = tmapreduce(max, ops) do currentDeleteOperator

            for op in deleteCandidates(g, currentDeleteOperator)
                isValidDelete(g, op) || continue
                op = score(op)
                op > currentDeleteOperator && (currentDeleteOperator = op)
            end
    
            return currentDeleteOperator
        end


        if bestDeleteOperator.scoreDelta > 0
            verbose && printState("Backward Search", bestDeleteOperator, score.cache)
            Delete!(g, bestDeleteOperator; verbose)
        else
            break
        end

    end

    return nothing
end



function deleteCandidates(g, op)
    #neighbors of y that are adjacent to x
    H = op.NAyx
    return (setH(op, Hᵢ) for Hᵢ in powerset(H))
end


####################################################################
# Insert/Delete Edges
####################################################################


"""
    Insert!(g, op::InsertOperator)
Modify the graph `g` by directing the edge `op.x`→`op.y` and orient all neighbors of `y` not connected to `x` toward `y`. Additionally use Meek rules to convert back to a CPDAG.
"""
function Insert!(g, op::InsertOperator; verbose)

    (; x, y, T) = op

    #Add a directed edge x→y (currently no edge present)
    addEdge!(g, x, y)

    #Orient all edges incident into child node
    for t in T
        orientEdge!(g, t, y) #t→y
    end

    #Extend to CPDAG 
    graphVStructure!(g; verbose)
    meekRules!(g; verbose)

    # PDAGtoDAG(g)
    # DAGtoCPDAG(g)

    return nothing
end

"""
Delete!(g, op::DeleteOperator)
Modify the graph `g` by removing the edge `op.x`→`op.y`. Additionally, orient all neighbors of `x` and `y` away from `x` and `y`.
"""
function Delete!(g, op::DeleteOperator; verbose)

    (; x, y, H) = op
    #remove directed and unidrected edges (x→y and x-y)
    removeEdge!(g, x, y)

    #Orient all vertices in H toward x and y
    for h in H
        orientEdge!(g, y, h) #y→h
        isNeighbor(g,x,h) && orientEdge!(g, x, h) #x→h (check if edge is undirected first)
    end

    #Extend to CPDAG 
    graphVStructure!(g; verbose)
    meekRules!(g; verbose)

    return nothing
end
