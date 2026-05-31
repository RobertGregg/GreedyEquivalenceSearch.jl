using GreedyEquivalenceSearch
using Test
using CSV, DataFrames
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



@testset "Loading Data" begin
    data = CSV.read("data/rCausalMGM_sim_data.csv",DataFrame) |> Matrix
    @test data isa Matrix
end



using BangBang, OhMyThreads

struct Immutable
    a
    b
end

x = Immutable(1, 2)

dist(x) = x.a^2 + x.b^2

function sumdist(x)
    
    return tmapreduce(dist,+,[setproperties!!(x; b) for b in 1:4])
end

sumdist(x)