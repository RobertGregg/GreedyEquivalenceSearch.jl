module GreedyEquivalenceSearch

using SmallCollections, SmallCombinatorics #for handling set operations, powersets, etc.
using Statistics, LinearAlgebra #covariance and solving systems
using OhMyThreads, ChunkSplitters #parallelization
using OhMyThreads: TaskLocalValue
using BangBang #update immutable operator properties


include("LRU.jl")
include("CustomPairIterators.jl")
include("GraphDataStructure.jl")
include("GraphAlgorithms.jl")
include("Operators.jl")
include("Score.jl")
include("MainAlgorithm.jl")

#Small helper functions
powerset(x::SmallSet) = Iterators.flatten(subsets(x,i) for i in 0:length(x))
adjacency_matrix(g) = BitMatrix(isParent(g,x,y) || isNeighbor(g,x,y)  for x in vertices(g), y in vertices(g))

export
    #GreedyEquivalenceSearch.jl
    powerset,
    adjacency_matrix,
    #LRU.jl
    LRUCache,
    place!,
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
    DeleteOperator,
    #Score.jl
    SufficientStats,
    CachedScore,
    score,
    #MainAlgorithm.jl
    forwardPhase!,
    backwardPhase!,
    ges,
    insertCandidates

end
