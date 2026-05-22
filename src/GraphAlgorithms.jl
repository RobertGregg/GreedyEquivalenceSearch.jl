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

    # Start backward search from y
    queue = [y]
    visited[y] = true

    while !isempty(queue)

        current = popfirst!(queue)

        # parents + undirected neighbors
        for v in descendents(g, current)

            if v == x
                return false   # semi-directed path exists
            end

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