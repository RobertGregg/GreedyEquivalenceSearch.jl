using GreedyEquivalenceSearch
using Test
# using CSV, DataFrames
using SmallCollections


@testset "GraphDataStructure" begin
    include("test_GraphDataStructure.jl")
end

@testset "Operators" begin
    include("test_Operators.jl")
end

@testset "GraphAlgorithms" begin
    include("test_GraphAlgorithms.jl")
end


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



# data = CSV.read("test/testDatasets/rCausalMGM_sim_data_large.csv",DataFrame) |> Matrix


# @test data isa Matrix