module GreedyEquivalenceSearchMakieExt
    
import GreedyEquivalenceSearch: plotNetwork
using GreedyEquivalenceSearch
using NetworkLayout, CairoMakie

#Smaller r will result in shorter edges
function nudge(r,p1,p2)
    θ =  atan(last(p2-p1), first(p2-p1))
    return p1 + [r*cos(θ), r*sin(θ)]
end


function plotNetwork(g; arrowgap=0.05, arrowsize=20, nodesize=30, layoutmethod=shell)
    
    fig = Figure(size = (600, 600))
    ax = Axis(fig[1, 1])
    hidedecorations!(ax)
    hidespines!(ax)

    
    #Calculate the node positions
    nodePositions = layoutmethod(adjacency_matrix(g) .| adjacency_matrix(g)')


    if !isempty(directedEdges(g))
        start = [nudge(arrowgap, nodePositions[x], nodePositions[y]) for (;x,y) in directedEdges(g)]
        stop = [nudge(arrowgap, nodePositions[y], nodePositions[x]) for (;x,y) in directedEdges(g)]
        arrows2d!(ax, start, stop; align=0.5, argmode = :endpoint, tiplength=10)
    end


    if !isempty(undirectedEdges(g))
        start = [nudge(arrowgap, nodePositions[x], nodePositions[y]) for (;x,y) in undirectedEdges(g)]
        stop = [nudge(arrowgap, nodePositions[y], nodePositions[x]) for (;x,y) in undirectedEdges(g)]
        arrows2d!(ax, start, stop; tip = Point2f[(0, 0), (0, 0), (0, 0)], align=0.5, argmode = :endpoint)
    end

    #Plot the nodes and add labels
    scatter!(ax, nodePositions, color=:dodgerblue, markersize=nodesize, strokewidth=1)
    text!(ax, nodePositions, text = string.(vertices(g)), align = (:center,:center))

    return fig
end

end