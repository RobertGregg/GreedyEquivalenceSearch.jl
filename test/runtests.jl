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



data = rand(100,50)
data .-= mean(data, dims=1)

stats = SufficientStats(data)
g = Graph(stats.variablesCount)

∅ = SmallSet{maxDegree(g),Int}()

validInserts = PriorityQueue{InsertOperator, Float64, DataStructures.FasterReverse}(
           DataStructures.FasterReverse()
       )

for (x,y) in allPairs(vertices(g))
    deltaScore = score(stats, y, x) - score(stats, y, ∅)
    validInserts[InsertOperator(x,y,∅)] = deltaScore
end