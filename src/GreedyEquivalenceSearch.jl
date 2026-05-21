module GreedyEquivalenceSearch

using SmallCollections, SmallCombinatorics #for handling node neighbors, powersets, etc.
using Statistics, LinearAlgebra #covariance and solving systems
using OhMyThreads #parallelization


#Small helper functions
powerset(x::AbstractSmallSet) = Iterators.flatten(subsets(x,i) for i in 0:length(x))




include("GraphDataStructure.jl")


export
    #GraphStructure.jl
    Graph,
    GraphEdge,
    heads,
    tails,
    maxDegree,
    vertices,
    nv,
    ne,
    addEdge!,
    removeEdge!,
    orientEdge!,
    hasEdge,
    isAdjacent,
    isNeighbor,
    isParent,
    isChild,
    isAncestor,
    isDescendent,
    isDirected,
    neighbors,
    parents,
    children,
    descendents,
    ancestors,
    adjacencies,
    allPairs,
    edges,
    undirectedEdges


end
