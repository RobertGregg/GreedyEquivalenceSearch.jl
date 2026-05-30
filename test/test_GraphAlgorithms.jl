
@testset "PDAG to CPDAG" begin
    
    g = Graph(6)
    
    # Unshielded collider: 1 → 3 ← 2, with 1 and 2 not adjacent
    addEdge!(g, 1, 3; directed=true)
    addEdge!(g, 2, 3; directed=true)
    
    # Shielded collider: 5 → 4 ← 6, but 5 and 6 ARE adjacent (shielded)
    addEdge!(g, 3, 4; directed=false)
    addEdge!(g, 5, 4; directed=true)
    addEdge!(g, 6, 4; directed=true)
    addEdge!(g, 5, 6; directed=false)
    
    
    graphVStructure!(g)

    allEdges = collect(edges(g))

    @test GraphEdge(1,3,true) in allEdges
    @test GraphEdge(2,3,true) in allEdges
    @test GraphEdge(3,4,false) in allEdges
    @test GraphEdge(4,5,false) in allEdges
    @test GraphEdge(4,6,false) in allEdges
    @test GraphEdge(5,6,false) in allEdges
end
