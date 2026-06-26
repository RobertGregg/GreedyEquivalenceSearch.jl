

@testset "PDAG Setup Comprehensive Tests" begin

    # --- TEST SET 1: Graph Initialization & Basic Properties ---
    @testset "Initialization & Counting" begin
        g = Graph(5)
        @test nv(g) == 5
        @test ne(g) == 0
        @test collect(vertices(g)) == 1:5

        # Test out-of-bounds or empty edges safely
        @test isempty(parents(g, 1))
        @test isempty(children(g, 1))
        @test isempty(neighbors(g, 1))
    end

    # --- TEST SET 2: Edge Modifications & Structural Logic ---
    @testset "Edge Mutations" begin
        g = Graph(4)

        # Add a directed edge: 1 → 2
        addDirectedEdge!(g, 1, 2)
        @test 2 ∈ children(g, 1)
        @test 1 ∈ parents(g, 2)
        @test 1 ∉ neighbors(g, 2)  # Should not be bidirectional
        @test ne(g) == 1

        # Add an undirected edge: 2 - 3
        addUndirectedEdge!(g, 2, 3)
        @test 3 ∈ neighbors(g, 2) && 2 ∈ neighbors(g, 3)
        @test ne(g) == 2

        # Orient an edge: Turn 2 - 3 into 2 → 3
        orientEdge!(g, 2, 3)
        @test 3 ∈ children(g, 2)
        @test 2 ∉ neighbors(g, 3)  # Backwards connection should be severed
        @test ne(g) == 2       # Edge count remains the same

        # Remove an edge
        removeDirectedEdge!(g, 1, 2)
        @test !isAdjacent(g, 1, 2)
        @test ne(g) == 1
    end

    # --- TEST SET 3: Relationship Predicates ---
    @testset "Vertex Relationships" begin
        # Building a canonical testing graph:
        # 1 → 2,  2 - 3,  3 → 4
        g = Graph(4)
        addDirectedEdge!(g, 1, 2)
        addUndirectedEdge!(g, 2, 3)
        addDirectedEdge!(g, 3, 4)

        # Directed checks
        @test isParent(g, 1, 2)
        @test isChild(g, 2, 1)
        @test !isNeighbor(g, 1, 2)
        @test isDirected(g, 1, 2)

        # Undirected checks
        @test isNeighbor(g, 2, 3)
        @test !isParent(g, 2, 3)
        @test !isDirected(g, 2, 3)
        @test isAdjacent(g, 3, 2)

        # Ancestor / Descendent shortcuts
        @test isAncestor(g, 1, 2)
        @test isAncestor(g, 2, 3)   # Undirected counts as ancestor
        @test isDescendent(g, 4, 3)
    end

    # --- TEST SET 4: Neighborhoods ---
    @testset "Neighborhoods" begin
        # Graph: 1 → 2, 1 - 3, 4 → 1
        g = Graph(4)
        addDirectedEdge!(g, 1, 2)
        addUndirectedEdge!(g, 1, 3)
        addDirectedEdge!(g, 4, 1)

        # 1) Checking standard streaming iterators
        @test neighbors(g, 1) == SmallSet{maxDegree(g)}([3])
        @test parents(g, 1) == SmallSet{maxDegree(g)}([4])
        @test children(g, 1) == SmallSet{maxDegree(g)}([2])
        @test adjacencies(g, 1) == SmallSet{maxDegree(g)}([2, 3, 4])
    end

    # --- TEST SET 5: Global Iterators & Clique Detection ---
    @testset "Global Iterators & Clique" begin
        # Pure undirected triangle: 1 - 2 - 3
        g = Graph(3)
        addUndirectedEdge!(g, 1, 2)
        addUndirectedEdge!(g, 2, 3)
        addUndirectedEdge!(g, 1, 3)

        # allCombinationPairs check
        pairs = collect(allCombinationPairs([1, 2, 3]))
        @test length(pairs) == 3
        @test (1, 2) ∈ pairs && (1, 3) ∈ pairs && (2, 3) ∈ pairs

        # Global edges count iterator checks
        @test length(collect(undirectedEdges(g))) == 3
    end
end