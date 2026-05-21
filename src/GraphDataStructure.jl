####################################################################
# Graph Structure
####################################################################

struct Graph{S<:AbstractVector{<:AbstractSet{<:Integer}}}
    heads::S
    tails::S
end

"""
    Graph(n; maxDegree=16)

Create an empty graph with `n` vertices and zero edges.

Edge information is stored as an adjacency list using two vectors of `SmallSet`s, making
set operations fast at the cost of a hard limit on the number of edges per vertex, given
by `maxDegree` (default 16).

Adjacency sets can be accessed via `heads(g, x)` and `tails(g, x)` for vertex `x`.

See also: [`maxDegree`](@ref), [`heads`](@ref), [`tails`](@ref)
"""
Graph(n; maxDegree=16) = Graph(
    [SmallSet{maxDegree,Int}() for _ in 1:n],
    [SmallSet{maxDegree,Int}() for _ in 1:n]
)

"""
    maxDegree(g::Graph)

Return the maximum number of edges per vertex in `g`.
"""
maxDegree(g::Graph) = capacity(eltype(g.heads))


"""
    heads(g,x)
Return the vertices that vertex `x` points to, undirected edges are consider bidirectional

Given the graph
    y → x - z
heads(g,x) = [z]
"""
heads(g,x) = g.heads[x] 

"""
    tails(g,x)
Return the vertices that vertex `x` points from,  undirected edges are consider bidirectional

Given the graph
    y → x - z
tails(g,x) = [y,z]
"""
tails(g,x) = g.tails[x] 

"""
    vertices(g)
An iterator through all the vertices of the graph `g` (i.e.,` 1:nv(g)`)
"""
vertices(g) = eachindex(g.heads)

"""
    nv(g)
Return the number of vertices in the graph `g`.
"""
nv(g) = length(vertices(g))

"""
    ne(g)
Return the number of edges in the graph `g`.
"""
function ne(g)
    
    edgecount = 0

    #Add two for each directed edge
    #Add one for each undirected edge (counted twice)
    for i in vertices(g)
        for h in heads(g,i)
            if i in heads(g,h)
                edgecount += 1
            else
                edgecount += 2
            end
        end
    end

    return edgecount ÷ 2
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
    g.heads[x] = push(heads(g,x),y)
    g.tails[y] = push(tails(g,y),x)

    if !directed
        g.heads[y] = push(heads(g,y),x)
        g.tails[x] = push(tails(g,x),y)
    end
    return nothing
end

"""
    removeEdge!(g,x,y)
Remove the edge `x`→`y` or `x`-`y` from the graph `g`. 
"""
function removeEdge!(g,x,y)

    g.heads[x] = delete(heads(g,x),y)
    g.tails[y] = delete(tails(g,y),x)

    g.heads[y] = delete(heads(g,y),x)
    g.tails[x] = delete(tails(g,x),y)
    return nothing
end

"""
    orientEdge!(g, x, y)
Update the edge `x`-`y` to `x`→`y` in the graph `g`. 

This function does not check for the presence of an edge beforehand. Orienting a nonexistent edge will do nothing.
"""
function orientEdge!(g, x, y)

    g.heads[y] = delete(heads(g,y),x)
    g.tails[x] = delete(tails(g,x),y)
    return nothing
end

####################################################################
# Relationship between two verticies
####################################################################

"""
    hasEdge(g, x, y)
Test if `x`-`y` or `x`→`y` in the graph `g`.
"""
hasEdge(g,x,y) = y ∈ heads(g,x)


"""
    isAdjacent(g, x, y)
Test if `x` and `y` are connected by any edge in the graph `g`.
"""
isAdjacent(g, x, y) = hasEdge(g,x,y) || hasEdge(g,y,x)


"""
    isNeighbor(g, x, y)
Test if `x` and `y` are connected by a undirected edge in the graph `g`.
"""
isNeighbor(g, x, y) = hasEdge(g,x,y) && hasEdge(g,y,x)


"""
    isParent(g, x, y)
Test if `x`→`y` in the graph `g`.
"""
isParent(g, x, y) = hasEdge(g,x,y) && !hasEdge(g,y,x)


"""
    isChild(g, x, y)
Test if `x`←`y` in the graph `g`.
"""
isChild(g, x, y) = !hasEdge(g,x,y) && hasEdge(g,y,x)

"""
    isAncestor(g, x, y)
Return `true` if `x`→`y` or `x`-`y` in the graph `g`.
"""
isAncestor(g, x, y) = hasEdge(g,x,y)

"""
    isDescendent(g, x, y)
Return `true` if `x`←`y` OR `x`-`y` in the graph `g`.
"""
isDescendent(g, x, y) = hasEdge(g,y,x)

"""
    isDirected(g, x, y)
Test if `x` and `y` are connected by a directed edge in the graph `g`, either x←y or x→y.
"""
isDirected(g, x, y) = hasEdge(g,x,y) ⊻ hasEdge(g,y,x)

####################################################################
# Neighborhood functions 
####################################################################

"""
    neighbors(g,x)
The set of undirected vertices connected to `x`.
"""
neighbors(g,x) = heads(g,x) ∩ tails(g,x)


"""
    parents(g,x)
The set of vertices with directed edges that point to `x`.
"""
parents(g, x) = setdiff(tails(g,x) , heads(g,x))


"""
    children(g,x)
The set of vertices with directed edges that point away from `x`.
"""
children(g, x) = setdiff(heads(g,x) , tails(g,x))


"""
    descendents(g,x)
The set of neighbors and children of `x`.
"""
descendents(g, x) = heads(g,x)

"""
    ancestors(g,x)
The set of neighbors and parents of `x`.
"""
ancestors(g, x) = tails(g,x)

"""
    adjacencies(g,x)
The set of all vertices connected to `x`.
"""
adjacencies(g, x) = heads(g,x) ∪ tails(g,x)


####################################################################
# Iterators 
####################################################################

"""
    allPairs(v)
Iterate through all pairs of elements in `v`. Assumes that all elements in `v` are unique.
"""
allPairs(v) = ((x,y) for (i,x) in enumerate(v) for y in Iterators.drop(v,i)) 


"""
    edges(g)

Return an iterator to generate all edges within the graph `g`. Similar to `Graphs.edges()` but does not double count undirected edges
"""
edges(g) = (
    GraphEdge(src, dst, !isNeighbor(g,src,dst))
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
    for dst in descendents(g,src)
    if src < dst && isNeighbor(g,src,dst)
)


