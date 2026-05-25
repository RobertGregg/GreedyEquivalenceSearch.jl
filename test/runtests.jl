using GreedyEquivalenceSearch
using SmallCollections
using Test
using DataStructures

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



data = rand(100,100)
data .-= mean(data, dims=1)

stats = SufficientStats(data)
g = Graph(stats.variablesCount)


@benchmark forwardPhase(g_copy, $stats) setup=(g_copy = deepcopy(g)) evals=1

@profview forwardPhase(g, stats)

@code_warntype forwardPhase(g, stats)