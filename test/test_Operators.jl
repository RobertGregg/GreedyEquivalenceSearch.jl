using GreedyEquivalenceSearch, SmallCollections
using Test

#=
┌────────────────── 5
│                   ↑
│                   │
│       1 ────────→ 3 ←──────── 2
│       │           │           │
│       │           │           │
│       └────────── 4 ──────────┘
│                   │
│                   ↓
└────────────────── 6 ────────→ 7
=#

@testset "Insert/Delete Operators" begin

    g = Graph(7)

    addEdge!(g, 1, 3; directed=true) 
    addEdge!(g, 2, 3; directed=true) 
    addEdge!(g, 1, 4; directed=false) 
    addEdge!(g, 3, 4; directed=false) 
    addEdge!(g, 2, 4; directed=false) 
    addEdge!(g, 3, 5; directed=true) 
    addEdge!(g, 4, 6; directed=true) 
    addEdge!(g, 5, 6; directed=false) 
    addEdge!(g, 6, 7; directed=true) 


    @test isValidInsert(g, 1, 5, SmallSet{16}(6)) == true # 6 blocks the path
    @test isValidInsert(g, 2, 6, SmallSet{16}(5)) == true
    @test isValidInsert(g, 1, 7, SmallSet{16}()) == true
    @test isValidInsert(g, 2, 5, SmallSet{16}()) == true

end


