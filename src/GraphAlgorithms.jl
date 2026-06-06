####################################################################
# GES Specific functions
####################################################################

"""
    isClique(g, nodes)
Return `true` if all vertices in `nodes` are undirected neighbors in the graph `g`.
"""
function isClique(g, nodes)

    for (x,y) in allCombinationPairs(nodes)
        if !isNeighbor(g, x, y)
            return false
        end
    end

    return true
end


#TODO eliminate allocations with visited and queue
"""
    isBlocked(g, x, y, nodesRemoved)

Return true if every semi-directed path from y to x intersects `nodesRemoved`.

A semi-directed path from y to x contains only:

    y → v₁ - v₂ → ... → x

where directed edges point away from y.
"""
function isBlocked(g, x, y, nodesRemoved)

    visited = falses(nv(g))

    # Remove blocked nodes
    for v in nodesRemoved
        visited[v] = true
    end

    # Start search from y
    queue = [y]
    visited[y] = true

    while !isempty(queue)

        current = popfirst!(queue)

        # children + undirected neighbors i.e., descendents(g, current)
        for v in Iterators.flatten((children(g,current), neighbors(g,current)))

            v == x && return false   # semi-directed path exists

            if !visited[v]
                visited[v] = true
                push!(queue, v)
            end

        end
    end

    return true
end



####################################################################
# Using Meek's Rules to Update PDAG
####################################################################


#Revert a graph to undirected edges and unshielded colliders
#An unshielded collider at node y look like: x → y ← z and requires that x and z are not adjacent.
function graphVStructure!(g)
    
    edgesToUndirect = Set{GraphEdge}()


    #Check through all directed edges
    for edge in directedEdges(g)

        undirectCurrentEdge = true
        (x,y) = edge.parent, edge.child

        #Find directed edges that share same child node
        #Check for unshielded collider
        for p in parents(g, y)
            if p≠x && !isAdjacent(g,x,p)
                undirectCurrentEdge = false
                break
            end
        end

        if undirectCurrentEdge
            push!(edgesToUndirect, edge)
        end

    end


    #Loop through edges and undirect edges not in unshielded colliders
    for edge in edgesToUndirect
        unorientEdge!(g,edge)
    end

end



function meekRules!(g)
    
    rulesFound = true

    while rulesFound
        
        rulesFound = false

        for edge in undirectedEdges(g)

            #For clarity extract the edge vertices
            (x, y) = edge.parent, edge.child

            if R1(g,x,y) || R2(g,x,y) || R3(g,x,y)
                #Change x-y to x→y
                orientEdge!(g, x, y)
                rulesFound = true
                break
            elseif R1(g,y,x) || R2(g,y,x) || R3(g,y,x)
                #Change y-x to y→x
                orientEdge!(g, y, x)
                rulesFound = true
                break
            end
        end

    end

    return nothing
end


function R1(g, x, y)
    #given x-y, look for patterns that match v₁→x and not(v₁→y)
    for v₁ in parents(g,x)
        if !isAdjacent(g,v₁,y)
            return true
        end
    end
    return false
end


function R2(g,x,y)
    #given x-y, look for patterns that match x→v₁→y
    for v₁ in children(g,x)
        if isParent(g,v₁,y)
            return true
        end
    end
    return false
end

function R3(g,x,y)
        
    #given x-y, find x-v₁→y and x-v₂→y and v₁-v₂
    for (v₁,v₂) in allCombinationPairs(neighbors(g,x))
        if isParent(g,v₁,y) && isParent(g,v₂,y) && !isAdjacent(g,v₁,v₂)
            return true
        end
    end
    
    return false
end



####################################################################
# Luttermann to Update PDAG
####################################################################

#1. Luttermann, M., Wienobst, M. & Liskiewicz, M. Practical Algorithms for Orientations of Partially Directed Graphical Models.

#A sink node is a node v such that:
#1. there are no directed edges pointing to v (i.e., children(g,v) = ∅)
#2. Every neighbor of v is connected to all other adjacent nodes of v (neighbors form a clique and are connected to all parents of v)

function isPotentialSink(g, v, verticesRemoved=BitSet())
    
    filteredParents = filter(!in(verticesRemoved), parents(g,v))
    filteredChildern = filter(!in(verticesRemoved), children(g,v))
    filteredNeighbors = filter(!in(verticesRemoved), neighbors(g,v))

    #No children
    !isempty( filteredChildern ) && return false

    #All neighbors are connected
    !isClique(g, filteredNeighbors) && return false

    #Every parent is connected to every neighbor 
    for p in filteredParents
        for y in filteredNeighbors
            !isAdjacent(g,y,p) && return false
        end
    end

    return true
end


#After adding an edge to a CPDAG, it may no longer be a CPDAG. To fix this, we can convert the new PDAG to a DAG then convert it to a CPDAG.


#This function is a little funny. The orginal algorithm has you removing nodes from the graph and creating a new one. Instead we create a set that holds all the removed nodes. Anytime we need the local structure around a vertex, we filter out the removed verticies (which is fast b/c we're using SmallSets and BitSets)
function PDAGtoDAG(g)

    verticesRemoved = BitSet()

    for _ in vertices(g) 
        for v in vertices(g)

            #Skip over removed vertices
            v ∈ verticesRemoved && continue

            if isPotentialSink(g, v, verticesRemoved)
                for x in filter(!in(verticesRemoved), adjacencies(g,v))
                    orientEdge!(g,x,v)
                end
                push!(verticesRemoved, v)
            end
        end
    end

end


####################################################################
# Topological Sort (Kahn's algorithm)
####################################################################
 
"""
    topologicalSort(g::Graph) -> Vector{Int}
 
Return a topological ordering of the vertices in `g` using Kahn's
algorithm: every vertex appears before all of its directed children.
 
Vertices with equal in-degree are processed in ascending numerical order
for a deterministic result.
 
Throws an error if the graph contains a cycle.
"""
function topologicalSort(g)
    n = nv(g)
    inDegree = [length(parents(g, v)) for v in vertices(g)]

    order = findall(iszero, inDegree)

    i = 1
    while i ≤ length(order)
        v = order[i]
        i += 1
        for w in children(g, v)
            inDegree[w] -= 1
            iszero(inDegree[w]) && push!(order, w)
        end
    end

    length(order) == n || error("Graph contains a cycle.")
    return order
end

####################################################################
# DAG → CPDAG
####################################################################
 
"""
    DAGtoCPDAG(dag::Graph) -> Graph
 
Convert a DAG to its **CPDAG** (Completed Partially Directed Acyclic Graph)
using Chickering's (2002) edge-labeling algorithm.
 
The CPDAG is the unique graph that represents the Markov equivalence class
of `dag`:
- **Compelled edges** must have the same orientation in every DAG that is
  Markov-equivalent to `dag`; they remain directed in the CPDAG.
- **Reversible edges** can be flipped without leaving the equivalence class;
  they appear as undirected edges in the CPDAG.
 
## Algorithm outline
 
1. **Consistent ordering** – sort the directed edges of `dag` by the
   topological rank of the child node (ties broken by the parent's rank).
   This ensures that whenever `z→x` and `x→y` are both edges, `z→x` is
   processed before `x→y`.
 
2. **Label each edge** – for every edge `x→y` in the ordering apply two rules:
 
   - **Rule 1 (compelled chain)**: if any `z ∈ pa(y)`, `z ≠ x`, has `z→x`
     already labeled *compelled*, then label `x→y` as *compelled*.
 
   - **Rule 2 (non-adjacent parent / v-structure)**: if any `z ∈ pa(y)`,
     `z ≠ x`, is not adjacent to `x`, then `x→y←z` is (or forces) a
     v-structure. Label `x→y` *compelled*, and propagate *compelled* to
     every other unknown edge into `y`.
 
   - If neither rule fires, label `x→y` as *reversible*.
 
3. **Assemble the CPDAG** – compelled edges stay directed; reversible edges
   become undirected.
 
## Examples
 
```julia
# V-structure: 1→3←2, with 1 and 2 non-adjacent → both edges compelled
dag = Graph(3)
addEdge!(dag, 1, 3)
addEdge!(dag, 2, 3)
cpdag = DAGtoCPDAG(dag)       # 1→3, 2→3  (directed)
 
# Chain: 1→2→3 → both edges reversible
dag = Graph(3)
addEdge!(dag, 1, 2)
addEdge!(dag, 2, 3)
cpdag = DAGtoCPDAG(dag)       # 1-2-3  (undirected)
 
# Fork: 1←2→3 → both edges reversible
dag = Graph(3)
addEdge!(dag, 2, 1)
addEdge!(dag, 2, 3)
cpdag = DAGtoCPDAG(dag)       # 1-2-3  (undirected)
```
"""
function DAGtoCPDAG(dag::Graph)
 
    # ── Step 1: consistent node ordering ─────────────────────────────
    topologicalOrder = topologicalSort(dag)

    # ── Step 2: consistent edge ordering ─────────────────────────────
    # Sort directed edges by (rank of child, rank of parent).
    # Key invariant: for any path z→x→y, the edge z→x sorts before x→y
    rankedEdges = GraphEdge[]
    for y in topologicalOrder, x in parents(dag, y)
        push!(rankedEdges, GraphEdge(x, y, true))
    end
 
    # ── Step 3: label each edge ───────────────────────────────────────
    # Initialize every edge as :unknown.
    labeledEdges = Dict(rankedEdges .=> :unknown)
 
    for edge in rankedEdges
        x, y = edge.parent, edge.child
 
        # Rule 2 (applied to a previous edge) may have pre-labeled this edge.
        labeledEdges[edge] ≠ :unknown && continue
 
        done = false
 
        # ── Rule 1: compelled chain ───────────────────────────────────
        # Premise: some other parent z of y has a *compelled* edge z→x.
        # Consequence: the "compelledness" propagates to x→y.
        #
        # Intuition: if z→x is locked in, and z is also a parent of y
        # (so z has two outgoing compelled paths toward y's neighborhood),
        # then x→y must also be fixed to avoid creating a spurious new
        # v-structure in some equivalent DAG.
        for z in parents(dag, y)
            z == x && continue
            if get(labeledEdges, GraphEdge(z, x, true), :unknown) === :compelled
                labeledEdges[GraphEdge(x, y, true)] = :compelled
                done = true
                break
            end
        end
 
        # ── Rule 2: non-adjacent parent (v-structure witness) ─────────
        # Premise: some other parent z of y is non-adjacent to x.
        # Consequence: x→y←z is a v-structure (actual or implied), so
        # both edges—and every other unknown edge into y—must be compelled.
        if !done
            for z in parents(dag, y)
                z == x && continue
                if !isAdjacent(dag, z, x)
                    labeledEdges[GraphEdge(x, y, true)] = :compelled
                    # Propagate to all other unknown edges into y
                    for w in parents(dag, y)
                        w == x && continue
                        if get(labeledEdges, GraphEdge(w, y,true), :unknown) === :unknown   
                            labeledEdges[GraphEdge(w, y,true)] = :compelled
                        end
                    end
                    done = true
                    break
                end
            end
        end
 
        # ── Neither rule fired → reversible ───────────────────────────
        done || (labeledEdges[GraphEdge(x, y, true)] = :reversible)
    end
 
    # ── Step 4: assemble the CPDAG ────────────────────────────────────
 
    for (edge, label) in labeledEdges
        if label === :reversible
            unorientEdge!(dag, edge)
        end
    end
 
    return dag
end

