using GreedyEquivalenceSearch
using SmallCollections
using DataStructures: MutableBinaryMaxHeap
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



data = rand(100,50)
data .-= mean(data, dims=1)

stats = SufficientStats(data)
g = Graph(stats.variablesCount)

∅ = SmallSet{maxDegree(g),Int}()

validInserts = MutableBinaryMaxHeap{InsertOperator}()

for (x,y) in allPairs(vertices(g))
    push!(validInserts,InsertOperator(x,y,∅,score(stats, y, x) - score(stats, y, ∅)))
end