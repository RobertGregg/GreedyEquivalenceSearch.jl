module GreedyEquivalenceSearch

using SmallCollections, SmallCombinatorics #for handling set operations, powersets, etc.
using Statistics, LinearAlgebra #covariance and solving systems
using OhMyThreads, ChunkSplitters #parallelization
using LRUCache #caching the scoring function


include("CustomPairIterators.jl")
include("GraphDataStructure.jl")
include("GraphAlgorithms.jl")
include("Operators.jl")
include("Score.jl")
include("MainAlgorithm.jl")

#Small helper functions
powerset(x::SmallSet) = Iterators.flatten(subsets(x,i) for i in 0:length(x))

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
