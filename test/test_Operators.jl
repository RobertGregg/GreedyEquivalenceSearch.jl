
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
    setType = eltype(g.parents)

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
    op1 = GreedyEquivalenceSearch.setT(op1, setType(6))

    op2 = InsertOperator(g, 2, 6)
    op2 = GreedyEquivalenceSearch.setT(op2, setType(5))


    @test isValid(g, op1) == true # 6 blocks the path
    @test isValid(g, op2) == true
    @test isValid(g, InsertOperator(g, 1, 7)) == true
    @test isValid(g, InsertOperator(g, 2, 5)) == true

end


