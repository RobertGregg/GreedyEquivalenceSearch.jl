
####################################################################
# Main Function
####################################################################

#TODO add support for graph node labels

"""
    ges(data; verbose=false)
Compute a causal graph for the given observed data.
"""
function ges(data::AbstractMatrix; verbose=false, progress=false, maxDegree=16, penalty=1.0)
        
    progress = ProgressUnknown(desc="Searching for Graph"; spinner=true, showspeed=true, enabled=progress)
    stats = SufficientStats(data; penalty)
    g = Graph(stats.variablesCount; maxDegree)
    score = CachedScore(stats, eltype(g.parents))

    search(g, score, InsertOperator; verbose, progress)
    search(g, score, DeleteOperator; verbose, progress)

    finish!(progress)
    return g
end



# executes when verbose flag is true
function printState(op, cache)
    # Helper function for consistent styled printing
    function printfield(label, value, color)
        printstyled(label, color=color, bold=true)
        print(value, " ")
    end

    # Extract and compute underlying data
    forward = op isa InsertOperator
    stage = forward ? "Forward Search" : "Backward Search"
    subset = forward ? collect(op.T) : collect(op.H)
    cache_pct = round(100 * length(cache) / cache.capacity, digits=3)

    printfield("[$stage]", "", forward ? :green : :red)
    printfield("Edge=", "$(op.x)→$(op.y)", :cyan)
    printfield("ΔScore=", round(op.scoreDelta, digits=4), :black)
    printfield("Subset=", subset, :magenta)


    printstyled("Cache=", color=:blue, bold=true)
    println(cache_pct, "%")
end



####################################################################
# Search Function for both Forward and Backward
####################################################################


#TODO Try local dicts + static schedule for each thread to avoid locks

function search(g, score, getOperator; verbose=false, progress)


    nodePairs = collect(allPermutationPairs(vertices(g)))

    #1. For each pair of nodes, generate all possible candidates
    #2. Test if candidate is valid
    #3. If valid, score and check against best found operator
    #4. After iterating all nodes, insert/delete the best candidate
    while true

        bestOperator = tmapreduce(max, nodePairs) do (x, y)

            currentOperator = getOperator(g, x, y) #Insert or Delete

            for op in getCandidates(g, currentOperator)
                isValid(g, op) || continue
                op = score(op)
                op > currentOperator && (currentOperator = op)
            end

            return currentOperator
        end


        if bestOperator.scoreDelta > 0
            verbose && printState(bestOperator, score.cache)
            applyOperator!(g, bestOperator; verbose)
        else
            break
        end

        next!(progress; showvalues = [("Number of Edges",ne(g)), ("Best Score",bestOperator.scoreDelta)])
    end

    return nothing
end



####################################################################
# Get all T/H sets given x and y
####################################################################

function getCandidates(g, op::InsertOperator)

    (; x, y) = op

    #neighbors of y that are not adjacent to x
    T = setdiff(neighbors(g, y), adjacencies(g, x))

    return (setT(op, Tᵢ) for Tᵢ in powerset(T))
end


function getCandidates(g, op::DeleteOperator)
    #neighbors of y that are adjacent to x
    H = op.NAyx
    return (setH(op, Hᵢ) for Hᵢ in powerset(H))
end


####################################################################
# Insert/Delete Edges
####################################################################

function applyOperator!(g, op::InsertOperator; verbose)

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

    return nothing
end


function applyOperator!(g, op::DeleteOperator; verbose)

    (; x, y, H) = op

    #remove directed and undirected edges (x→y and x-y)
    removeEdge!(g, x, y)

    #Orient all vertices in H toward x and y
    for h in H
        orientEdge!(g, y, h) #y→h
        isNeighbor(g, x, h) && orientEdge!(g, x, h) #x→h (check if edge is undirected first)
    end

    #Extend to CPDAG 
    graphVStructure!(g; verbose)
    meekRules!(g; verbose)

    return nothing
end
