####################################################################
# GES Specific functions
####################################################################

"""
    isClique(g, nodes)
Return `true` if all vertices in `nodes` are undirected neighbors in the graph `g`.
"""
function isClique(g, nodes)

    for (x,y) in allPairs(nodes)
        if !isNeighbor(g, x, y)
            return false
        end
    end

    return true
end



#Maybe make a functor to store visited and queue?
"""
    isBlocked(g, x, y,  nodesRemoved, visited::Vector, queue::BitSet)
Return `true` if there is no semi-directed path between `x` and `y` in the graph `g`.

A set of vertices (`nodesRemoved`) can be removed from the graph before searching for a semi-directed path.

`visited` is a BitVector sized by the number of vertices in the graph `g`.

`queue` is a BitSet used to search through the graph.

A semi-directed path between `x` and `y` is a list of edges in `g` where every edge is either undirected or points toward `y`. 

    x → v₁ - v₂ → y ✓
    x → v₁ ← v₂ - y ✖
"""
function isBlocked(g, x, y, nodesRemoved, visited::BitVector, queue::BitSet)

    #For there to be a semi-directed path...
    #src needs to have a descendent not in nodesRemoved
    descendents(g,x) ⊆ nodesRemoved && return true
    #dst needs an ancestor not in nodesRemoved
    ancestors(g,y) ⊆ nodesRemoved && return true


    #Keep track of all the nodes visited
    visited .= false

    # mark excluded vertices as visited
    for vᵢ in nodesRemoved 
        visited[vᵢ] = true
    end
    
    #Put y in the queue and mark as visited
    push!(empty!(queue),y)
    visited[y] = true

    #We're actually going to work backwards because nodesRemoved are nodes all connected to y, meaning y is likely to have less edges compared to x. (using BFS)
    while !isempty(queue)
        currentNode = popfirst!(queue) # get new element from queue
        for vᵢ in ancestors(g,currentNode)
            vᵢ == x && return false
            if !visited[vᵢ]
                push!(queue, vᵢ) # push onto queue
                visited[vᵢ] = true
            end
        end
    end

    return true

end



####################################################################
# Using Meek's Rules to Update PDAG
####################################################################


#Revert a graph to undirected edges and unshielded colliders (i.e. parents not adjacent)
function graphVStructure!(g)
    
    #undirect an edge if it does not participate in an unshielded collider
    for edge in edges(g)
        if edge.directed && allshielded(g,edge) 
            #undirect by adding reverse edge
            addEdge!(g, edge.child, edge.parent)
        end
    end
end

allshielded(g,x,y) = all(isAdjacent(g, p, x) for p in parents(g, y) if p ≠ x)
allshielded(g,edge) = allshielded(g, edge.parent, edge.child)


function meekRules!(g)
    
    rulesFound = true

    while rulesFound
        
        rulesFound = false

        for edge in undirectedEdges(g)

            #For clarity extract the edge vertices
            (x, y) = edge.parent, edge.child

            #TODO Can multiple rules pass for the same edge?
            if R1(g,x,y) || R2(g,x,y) || R3(g,x,y)
                #Change x-y to x→y
                orientEdge!(g, x, y)
                rulesFound = true
            elseif R1(g,y,x) || R2(g,y,x) || R3(g,y,x)
                #Change y-x to y→x
                orientEdge!(g, y, x)
                rulesFound = true
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
    for (v₁,v₂) in allPairs(neighbors(g,x))
        if isParent(g,v₁,y) && isParent(g,v₂,y) && !isAdjacent(g,v₁,v₂)
            return true
        end
    end
    
    return false
end