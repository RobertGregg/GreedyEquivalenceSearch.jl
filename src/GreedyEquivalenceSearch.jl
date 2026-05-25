module GreedyEquivalenceSearch

using SmallCollections, SmallCombinatorics #for handling node neighbors, powersets, etc.
using Statistics, LinearAlgebra #covariance and solving systems
using DataStructures
using OhMyThreads #parallelization


#Small helper functions
powerset(x::AbstractSmallSet) = Iterators.flatten(subsets(x,i) for i in 0:length(x))




include("GraphDataStructure.jl")
include("GraphAlgorithms.jl")
include("Operators.jl")
include("Score.jl")
include("MainAlgorithm.jl")


export
    #GreedyEquivalenceSearch.jl
    powerset,
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
    allPermutationPairs,
    allCombinationPairs,
    edges,
    undirectedEdges,
    directedEdges,
    #GraphAlgorithms.jl
    isClique,
    isBlocked,
    graphVStructure!,
    #Operators.jl
    isValidInsert,
    isValidDelete,
    InsertOperator,
    #Score.jl
    SufficientStats,
    score,
    #MainAlgorithm.jl
    forwardPhase

end
