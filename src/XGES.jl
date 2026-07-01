#=

1. Use ordered set to store the operators
2. How to save the edge changes when they occur?
3. Add additional validity tests (for sets E and F)
=#


function XGES0(data::AbstractMatrix; verbose=false, progress=false, maxDegree=16, penalty=1.0)

    stats = SufficientStats(data; penalty)
    g = Graph(stats.variablesCount; maxDegree)
    setType =  eltype(g.parents)

    score = CachedScore(stats, setType)

    operatorSet = Set{Operator{setType}}(
        score(InsertOperator(g, x, y)) for (x, y) in allPermutationPairs(vertices(g))
    )

    while !isempty(operatorSet)

        bestOperator = pop!(operatorSet)

        if isValid(g, bestOperator) && bestOperator.scoreDelta > 0
            verbose && printState(bestOperator, score.cache)
            applyOperator(g, bestOperator; verbose)
        end
    end

    return g
end