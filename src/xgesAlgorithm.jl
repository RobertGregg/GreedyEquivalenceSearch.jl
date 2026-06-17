

function XGES0(data::AbstractMatrix; verbose=false, maxDegree=16, penalty=1.0)

    stats = SufficientStats(data; penalty)
    g = Graph(stats.variablesCount; maxDegree)
    setType =  eltype(g.parents)

    score = CachedScore(stats, setType)

    ∅ = setType()

    operatorSet = SortedSet{Operator{setType}, Base.Order.ReverseOrdering}(
        Base.Order.ReverseOrdering(),
        InsertOperator(g, x, y, ∅, score) for (x, y) in allPermutationPairs(vertices(g))
    )

    while !isempty(operatorSet)

        bestOperator = popfirst!(operatorSet)

        if isValid(g, bestOperator) && bestOperator.scoreDelta > 0
            verbose && printState(bestOperator, score.cache, operatorSet)
            applyOperator(g, bestOperator, operatorSet, score)
        end
    end

    return g
end



function applyOperator(g, op::InsertOperator, operatorSet, score)

    (; x, y, T) = op

    #Add a directed edge x→y (currently no edge present)
    addDirectedEdge!(g, x, y)
    addAllCandidates(g, x, y, operatorSet, score, U2_NONE_TO_DIRECTED)

    #Orient all edges incident into child node
    for t in T
        orientEdge!(g, t, y) #t→y
        addAllCandidates(g, x, y, operatorSet, score, U4_UNDIRECTED_TO_DIRECTED)
    end

    #Extend to CPDAG 
    graphVStructure!(g, operatorSet, score)
    meekRules!(g, operatorSet, score)



    return nothing
end


function applyOperator(g, op::DeleteOperator, operatorSet, score)

    (; x, y, C) = op

    #remove directed and unidrected edges (x→y and x-y)
    if isDirected(g, x, y)
        removeDirectedEdge!(g, x, y)
        addAllCandidates(g, x, y, operatorSet, score, U5_DIRECTED_TO_NONE)
    else
        removeUndirectedEdge!(g, x, y)
        addAllCandidates(g, x, y, operatorSet, score, U3_UNDIRECTED_TO_NONE)
    end

    #Orient all vertices in H toward x and y
    H = setdiff(neighbors(g, y) ∩ adjacencies(g, x), C)
    for h in H
        orientEdge!(g, y, h) #y→h
        addAllCandidates(g, y, h, operatorSet, score, U4_UNDIRECTED_TO_DIRECTED)

        if isNeighbor(g,x,h)
            orientEdge!(g, x, h) #x→h
            addAllCandidates(g, x, h, operatorSet, score, U4_UNDIRECTED_TO_DIRECTED)
        end
    end

    #Extend to CPDAG 
    graphVStructure!(g, operatorSet, score)
    meekRules!(g, operatorSet, score)



    return nothing
end


# #executes when verbose flag is true
function printState(op::Operator, cache, operatorSet)

    forward = op isa InsertOperator
    stage = forward ? "Forward" : "Backward"

    subset = forward ? collect(op.T) : collect(op.C)

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
    print(cache_pct, "%")

    print(" ")

    printstyled("Operator Size=", color=:yellow, bold=true)
    println(length(operatorSet))
end

