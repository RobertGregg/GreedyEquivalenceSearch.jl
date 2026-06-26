
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

    addDirectedEdge!(g, 1, 3)
    addDirectedEdge!(g, 2, 3)
    addUndirectedEdge!(g, 1, 4)
    addUndirectedEdge!(g, 3, 4)
    addUndirectedEdge!(g, 2, 4)
    addDirectedEdge!(g, 3, 5)
    addDirectedEdge!(g, 4, 6)
    addUndirectedEdge!(g, 5, 6)
    addDirectedEdge!(g, 6, 7)


    op1 = InsertOperator(g, 1, 5)
    op1 = GreedyEquivalenceSearch.setT(op1, SmallBitSet{UInt8}(6))

    op2 = InsertOperator(g, 2, 6)
    op2 = GreedyEquivalenceSearch.setT(op2, SmallBitSet{UInt8}(5))


    @test isValidInsert(g, op1) == true # 6 blocks the path
    @test isValidInsert(g, op2) == true
    @test isValidInsert(g, InsertOperator(g, 1, 7)) == true
    @test isValidInsert(g, InsertOperator(g, 2, 5)) == true

end


