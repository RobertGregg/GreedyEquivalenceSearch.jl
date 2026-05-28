using GreedyEquivalenceSearch
using SmallCollections
using Test

@testset "Powerset Iterator" begin
    function test_powerset(x)
        s = 0
    
        for xᵢ in powerset(x)
            s += length(xᵢ)
        end
        return s
    end

    s = SmallSet{16}([1,3,5])

    @test test_powerset(s) == 12
end



data = randn(100,100)
data .-= mean(data, dims=1)


@benchmark ges($data)

@profview ges(data)

@code_warntype forwardPhase(g, stats)


g = ges(data; verbose=true)


for (x,y) in allPermutationPairs(vertices(g))
    for op in candidates(g,x,y)
        if isValidInsert(g, op)
            deltaScore = score(y, op.T ∪ parents(g,y) ∪ x) - score(y, op.T ∪ parents(g,y))
        end
    end
end

v=1:10
op = tmapreduce(max, ((x,y) for x in 1:10 for y in 1:10)) do (x,y)
    x + y
end