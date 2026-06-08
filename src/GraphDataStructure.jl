####################################################################
# Graph Structure
####################################################################

struct Graph{S<:AbstractVector{<:AbstractSet{<:Integer}}}
    parents::S
    neighbors::S
    children::S
end

"""
    Graph(n; maxDegree=16)

Create an empty graph with `n` vertices and zero edges.

Edge information is stored as an adjacency list using three vectors of `SmallSet`s, making
set operations fast at the cost of a hard limit on the number of edges per vertex, given
by `maxDegree` (default 16).

See also: [`maxDegree`](@ref)
"""
function Graph(n; maxDegree=16)
    
    if n ≤ 1024
        N = getUIntType(n)
        return Graph(
            [SmallBitSet{N}() for _ in 1:n],
            [SmallBitSet{N}() for _ in 1:n],
            [SmallBitSet{N}() for _ in 1:n]
            )
    end


    return Graph(
    [SmallSet{maxDegree, Int}() for _ in 1:n],
    [SmallSet{maxDegree, Int}() for _ in 1:n],
    [SmallSet{maxDegree, Int}() for _ in 1:n]
    )
end

"""
    maxDegree(g::Graph)

Return the maximum allowed number of edges per vertex in `g`.
"""
maxDegree(g::Graph) = SmallCollections.capacity(eltype(g.parents))


####################################################################
# Neighborhood functions 
####################################################################

"""
    parents(g,x)
Return the vertices that have a directed edge pointing to vertex `x`

Given the graph
    y → x → z
heads(g,x) = [y]
"""
parents(g,x) = g.parents[x] 


"""
    neighbors(g,x)
Return the vertices that have an undirected edge to `x`

Given the graph
    y - x - z
neighbors(g,x) = [y,z]
"""
neighbors(g,x) = g.neighbors[x] 


"""
    children(g,x)
Return the vertices that have a directed edge pointing from vertex `x`

Given the graph
    y → x → z
children(g,x) = [z]
"""
children(g,x) = g.children[x] 


"""
    descendents(g,x)
The set of neighbors or children of `x`.
"""
descendents(g, x) = neighbors(g,x) ∪ children(g, x)


"""
    ancestors(g,x)
The set of neighbors or parents of `x`.
"""
ancestors(g, x) = neighbors(g,x) ∪ parents(g, x)


"""
    adjacencies(g,x)
The set of all vertices connected to `x`.
"""
adjacencies(g, x) = neighbors(g,x) ∪ parents(g, x) ∪ children(g, x)


####################################################################
# Counting Vertices and Edges
####################################################################

"""
    vertices(g)
An iterator through all the vertices of the graph `g` (i.e.,` 1:nv(g)`)
"""
vertices(g) = eachindex(g.parents)

"""
    nv(g)
Return the number of vertices in the graph `g`.
"""
nv(g) = length(vertices(g))


#TODO Get back to this
"""
    ne(g)
Return the number of edges in the graph `g`.
"""
function ne(g)
    
    edgecount = 0

    for _ in edges(g)
        edgecount += 1
    end

    return edgecount
end


function Base.show(io::IO, ::MIME"text/plain", g::Graph)

    numEdges = ne(g)

    println(io,"PDAG with $(nv(g)) vertices and $(numEdges) Edges:")

    printIterator(io, edges(g), numEdges)
    
end


#Used to dynamically print graph edges
function printIterator(io, itr, iterLength)
    sz = displaysize(io)
    screenheight = sz[1] - 4 
    pre = " "
    halfheight = div(screenheight, 2) - 1

    if iterLength > screenheight
        for (idx, item) in enumerate(itr)
            # Print the top chunk
            if idx <= halfheight
                println(io, pre, item)
            # Print the middle ellipsis exactly once
            elseif idx == halfheight + 1
                println(io, pre, "\u22ee")
            # Print the bottom chunk
            elseif idx > (iterLength - halfheight)
                println(io, pre, item)
            end
        end
    else
        for i in itr 
            println(io, pre, i)
        end
    end
end

####################################################################
# Defining Edges
####################################################################

"""
    GraphEdge(parent, child, directed::Bool)
A data type to hold edge information.
"""
struct GraphEdge
    parent::Int
    child::Int
    directed::Bool
end

#overload to print Edge type
function Base.show(io::IO, edge::GraphEdge)

    arrow = edge.directed ? " → " : " - "

    print(io, edge.parent, arrow, edge.child)
end

####################################################################
# Methods to modify Graph edges
####################################################################

"""
    addEdge!(g,x,y; directed=true)
Add the edge `x`→`y` to the graph `g`. 

The directed keyword can be set to false to add an undirected edge: `x`-`y`.

This function does not check for the presence of an edge beforehand.
"""
function addEdge!(g,x,y; directed=true)

    if directed
        g.children[x] = push(children(g,x),y)
        g.parents[y] = push(parents(g,y),x)
    else
        g.neighbors[x] = push(neighbors(g,x),y)
        g.neighbors[y] = push(neighbors(g,y),x)
    end
    return nothing
end

addEdge!(g, edge::GraphEdge) = addEdge!(g, edge.parent, edge.child; directed=edge.directed)

"""
removeEdge!(g,x,y)
Remove the edge `x`→`y` or `x`-`y` from the graph `g`. 
"""
function removeEdge!(g,x,y)
    
    #Removing potential undirected edge
    g.neighbors[x] = delete(neighbors(g,x),y)
    g.neighbors[y] = delete(neighbors(g,y),x)

    #Removing potential directed edge
    g.children[x] = delete(children(g,x),y)
    g.parents[y] = delete(parents(g,y),x)

    return nothing
end

removeEdge!(g, edge::GraphEdge) = removeEdge!(g, edge.parent, edge.child)

"""
orientEdge!(g, x, y)
Update the edge `x`-`y` to `x`→`y` in the graph `g`. 

This function does not check for the presence of an edge beforehand.
"""
function orientEdge!(g, x, y)
    
    #Remove undirected edge
    g.neighbors[x] = delete(neighbors(g,x),y)
    g.neighbors[y] = delete(neighbors(g,y),x)

    #Add directed edge
    g.children[x] = push(children(g,x),y)
    g.parents[y] = push(parents(g,y),x)

    return nothing
end
    
orientEdge!(g, edge::GraphEdge) = orientEdge!(g, edge.parent, edge.child)

"""
unorientEdge!(g, x, y)
Update the edge `x`→`y` to `x`-`y` in the graph `g`. 
"""
function unorientEdge!(g, x, y)
    
    #Remove directed edge
    g.children[x] = delete(children(g,x),y)
    g.parents[y] = delete(parents(g,y),x)

    #Add undirected edge
    g.neighbors[x] = push(neighbors(g,x),y)
    g.neighbors[y] = push(neighbors(g,y),x)
    return nothing
end

unorientEdge!(g, edge::GraphEdge) = unorientEdge!(g, edge.parent, edge.child)

####################################################################
# Relationship between two verticies
####################################################################


"""
    isNeighbor(g, x, y)
Test if `x` and `y` are connected by a undirected edge in the graph `g`.
"""
isNeighbor(g, x, y) = x ∈ neighbors(g,y)


"""
    isParent(g, x, y)
Test if `x`→`y` in the graph `g`.
"""
isParent(g, x, y) = x ∈ parents(g,y)


"""
    isChild(g, x, y)
Test if `x`←`y` in the graph `g`.
"""
isChild(g, x, y) = x ∈ children(g,y)


"""
    isDirected(g, x, y)
Test if `x` and `y` are connected by a directed edge in the graph `g`, either x←y or x→y.
"""
isDirected(g, x, y) = isParent(g, x, y) ⊻ isParent(g, y, x)


"""
    isAdjacent(g, x, y)
Test if `x` and `y` are connected by any edge in the graph `g`.
"""
isAdjacent(g, x, y) = isNeighbor(g,x,y) || isDirected(g, x, y)


"""
    isAncestor(g, x, y)
Return `true` if `x`→`y` or `x`-`y` in the graph `g`.
"""
isAncestor(g, x, y) = isNeighbor(g,x,y) || isParent(g, x, y)

"""
    isDescendent(g, x, y)
Return `true` if `x`←`y` OR `x`-`y` in the graph `g`.
"""
isDescendent(g, x, y) = isNeighbor(g,x,y) || isParent(g, y, x)


####################################################################
# Iterators 
####################################################################

"""
    edges(g)

Return an iterator to generate all edges within the graph `g`. Similar to `Graphs.edges()` but does not double count undirected edges
"""
edges(g) = (
    GraphEdge(src, dst, isDirected(g,src,dst))
    for src in vertices(g)
    for dst in descendents(g,src)
    if src < dst || isDirected(g,src,dst)
)

"""
    undirectedEdges(g)

Return an iterator to generate all edges within the graph `g` that are undirected.
"""
undirectedEdges(g) =  (
    GraphEdge(src, dst, false)
    for src in vertices(g)
    for dst in neighbors(g,src)
    if src < dst
)


"""
    directedEdges(g)

Return an iterator to generate all edges within the graph `g` that are directed.
"""
directedEdges(g) =  (
    GraphEdge(src, dst, true)
    for src in vertices(g)
    for dst in children(g,src)
)


