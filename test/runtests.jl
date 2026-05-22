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
