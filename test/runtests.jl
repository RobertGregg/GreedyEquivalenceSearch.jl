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



g = Graph(5)

addEdge!(g,1,2,directed=false)
addEdge!(g,1,3,directed=false)
addEdge!(g,1,4,directed=false)
addEdge!(g,2,4,directed=true)
addEdge!(g,3,4,directed=true)
addEdge!(g,4,5,directed=false)

getDAG(g)




g1 = Graph(5)

addEdge!(g1, 1, 2, directed=false)
addEdge!(g1, 1, 3, directed=false)
addEdge!(g1, 2, 4, directed=true)
addEdge!(g1, 3, 4, directed=true)
addEdge!(g1, 4, 5, directed=false) 
# Consistent extension will orient: 1->2, 1->3, 4->5
getDAG(g1)


g2 = Graph(5)

addEdge!(g2, 1, 2, directed=false)
addEdge!(g2, 1, 3, directed=false)
addEdge!(g2, 2, 3, directed=false) # The chord
addEdge!(g2, 2, 4, directed=false)
addEdge!(g2, 3, 4, directed=false)
addEdge!(g2, 4, 5, directed=false)
# One valid extension: 1->2, 1->3, 2->3, 2->4, 3->4, 4->5
getDAG(g2)


g3 = Graph(5)

addEdge!(g3, 1, 2, directed=true)
addEdge!(g3, 2, 3, directed=false)
addEdge!(g3, 3, 4, directed=false)
addEdge!(g3, 4, 5, directed=false)
# Consistent extension forces a pure chain: 1->2->3->4->5
getDAG(g3)


#Topological sort test

dag = Graph(7)
addEdge!(dag, 7, 2)
addEdge!(dag, 7, 3)
addEdge!(dag, 2, 4)
addEdge!(dag, 3, 4)  # 4 has two parents: 2 and 3
addEdge!(dag, 3, 5)
addEdge!(dag, 4, 6)
addEdge!(dag, 5, 1)
addEdge!(dag, 6, 1)  # 7 has two parents: 5 and 6


DAGtoCPDAG(dag)