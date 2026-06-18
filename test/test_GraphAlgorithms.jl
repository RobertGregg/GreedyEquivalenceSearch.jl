
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

    @test GraphEdge(1, 3, true) in allEdges
    @test GraphEdge(2, 3, true) in allEdges
    @test GraphEdge(3, 4, false) in allEdges
    @test GraphEdge(4, 5, false) in allEdges
    @test GraphEdge(4, 6, false) in allEdges
    @test GraphEdge(5, 6, false) in allEdges
end



####################################################################
# Small helper for the tests: build a graph from a list of edges.
# Each edge is (x, y, directed::Bool); x→y if directed, x-y otherwise.
####################################################################
function buildGraph(n, edgeList)
    g = Graph(n)
    for (x, y, directed) in edgeList
        addEdge!(g, x, y; directed=directed)
    end
    return g
end

@testset "GraphDataStructure + GES functions" begin

    ################################################################
    # graphVStructure!
    ################################################################
    @testset "graphVStructure!" begin

        @testset "unshielded collider is preserved" begin
            # x → z ← y, x and y NOT adjacent => true v-structure
            g = buildGraph(3, [(1, 3, true), (2, 3, true)])
            graphVStructure!(g)

            @test isParent(g, 1, 3)
            @test isParent(g, 2, 3)
            @test !isNeighbor(g, 1, 3)
            @test !isNeighbor(g, 2, 3)
            @test !isAdjacent(g, 1, 2)
        end

        @testset "chain is not a v-structure" begin
            # a → b → c is reverted entirely to a - b - c
            g = buildGraph(3, [(1, 2, true), (2, 3, true)])
            graphVStructure!(g)

            @test isNeighbor(g, 1, 2)
            @test isNeighbor(g, 2, 3)
            @test !isParent(g, 1, 2)
            @test !isParent(g, 2, 3)
        end

        @testset "shielded collider is reverted (triangle)" begin
            # x → z ← y but x → y too, so x,y are adjacent: shielded,
            # the whole triangle must become undirected
            g = buildGraph(3, [(1, 3, true), (2, 3, true), (1, 2, true)])
            graphVStructure!(g)

            @test isNeighbor(g, 1, 3)
            @test isNeighbor(g, 2, 3)
            @test isNeighbor(g, 1, 2)
            @test ne(g) == 3
        end

        @testset "diamond keeps only the real collider" begin
            # a → b → d ← c ← a, with b,c not adjacent
            g = buildGraph(4, [(1, 2, true), (1, 3, true), (2, 4, true), (3, 4, true)])
            graphVStructure!(g)

            @test isParent(g, 2, 4)
            @test isParent(g, 3, 4)
            @test isNeighbor(g, 1, 2)
            @test isNeighbor(g, 1, 3)
        end

        @testset "multiple disjoint v-structures" begin
            # a → b ← c   and   d → e ← f, unrelated components
            g = buildGraph(6, [(1, 2, true), (3, 2, true), (4, 5, true), (6, 5, true)])
            graphVStructure!(g)

            @test isParent(g, 1, 2) && isParent(g, 3, 2)
            @test isParent(g, 4, 5) && isParent(g, 6, 5)
        end

        @testset "no-op on an already-undirected graph" begin
            g = buildGraph(3, [(1, 2, false), (2, 3, false)])
            graphVStructure!(g)

            @test isNeighbor(g, 1, 2)
            @test isNeighbor(g, 2, 3)
        end
    end

    ################################################################
    # meekRules!
    ################################################################
    @testset "meekRules!" begin

        @testset "Rule 1: avoid creating a new unshielded collider" begin
            # v1 → x - y, v1 not adjacent to y  =>  x → y
            g = buildGraph(3, [(1, 2, true), (2, 3, false)])
            meekRules!(g)

            @test isParent(g, 2, 3)
            @test !isNeighbor(g, 2, 3)
        end

        @testset "Rule 2: avoid creating a directed cycle" begin
            # x → v1 → y, x - y  =>  x → y
            g = buildGraph(3, [(1, 2, true), (2, 3, true), (1, 3, false)])
            meekRules!(g)

            @test isParent(g, 1, 3)
            @test !isNeighbor(g, 1, 3)
        end

        @testset "Rule 3" begin
            # x - v1 → y, x - v2 → y, v1/v2 not adjacent, x - y  =>  x → y
            # x=1, y=2, v1=3, v2=4
            g = buildGraph(4, [
                (1, 3, false), (3, 2, true),
                (1, 4, false), (4, 2, true),
                (1, 2, false),
            ])
            meekRules!(g)

            @test isParent(g, 1, 2)
            @test !isNeighbor(g, 1, 2)
            # the supporting edges are not determined further and stay undirected
            @test isNeighbor(g, 1, 3)
            @test isNeighbor(g, 1, 4)
        end

        @testset "no rule applies: isolated undirected edge is untouched" begin
            g = buildGraph(2, [(1, 2, false)])
            meekRules!(g)

            @test isNeighbor(g, 1, 2)
            @test !isParent(g, 1, 2)
            @test !isParent(g, 2, 1)
        end

        @testset "fully directed acyclic graph is left alone" begin
            # meekRules! only acts on undirected edges
            g = buildGraph(3, [(1, 2, true), (2, 3, true)])
            meekRules!(g)

            @test isParent(g, 1, 2)
            @test isParent(g, 2, 3)
        end
    end

    ################################################################
    # Integration: graphVStructure! followed by meekRules!
    ################################################################
    @testset "Integration" begin

        @testset "diamond DAG converges to its CPDAG" begin
            # a → b → d ← c ← a ; b,c not adjacent
            g = buildGraph(4, [(1, 2, true), (1, 3, true), (2, 4, true), (3, 4, true)])
            graphVStructure!(g)
            meekRules!(g)

            @test isParent(g, 2, 4) && isParent(g, 3, 4)
            @test isNeighbor(g, 1, 2)
            @test isNeighbor(g, 1, 3)
        end

        @testset "a third unrelated parent protects two edges at once" begin
            # a → b, b → c, a → c (a triangle, would be fully shielded on
            # its own), plus d → c where d is NOT adjacent to a or b.
            # d makes BOTH a-c and b-c unshielded colliders (a,d) and (b,d),
            # so a→c, b→c, and d→c all stay directed; only a-b (which has
            # no such protection) gets undirected.
            g = buildGraph(4, [
                (1, 2, true),  # a -> b
                (2, 3, true),  # b -> c
                (1, 3, true),  # a -> c
                (4, 3, true),  # d -> c   (d not adjacent to a or b)
            ])
            graphVStructure!(g)

            @test isNeighbor(g, 1, 2)
            @test isParent(g, 1, 3)
            @test isParent(g, 2, 3)
            @test isParent(g, 4, 3)

            meekRules!(g)
            # no further orientation is forced: a-b stays undirected
            @test isNeighbor(g, 1, 2)
            @test !isParent(g, 1, 2) && !isParent(g, 2, 1)
        end

        @testset "random DAGs: skeleton preserved and no edge is ever reversed" begin
            Random.seed!(42)

            for _ in 1:25
                n = rand(4:8)
                order = randperm(n)
                g = Graph(n)
                originalEdges = Set{Tuple{Int,Int}}()

                for i in 1:n, j in (i+1):n
                    if rand() < 0.4
                        x, y = order[i], order[j]   # respects topological order => acyclic
                        addEdge!(g, x, y; directed=true)
                        push!(originalEdges, (x, y))
                    end
                end

                graphVStructure!(g)
                meekRules!(g)

                # skeleton must be unchanged
                for (x, y) in originalEdges
                    @test isAdjacent(g, x, y)
                end

                # a directed edge must never end up reversed from the original DAG
                for (x, y) in originalEdges
                    @test !isParent(g, y, x)
                end

                # no new adjacencies introduced
                for x in 1:n, y in (x+1):n
                    if (x, y) ∉ originalEdges && (y, x) ∉ originalEdges
                        @test !isAdjacent(g, x, y)
                    end
                end
            end
        end
    end

end