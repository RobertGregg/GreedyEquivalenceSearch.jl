module GreedyEquivalenceSearch

using SmallCollections, SmallCombinatorics #for handling set operations, powersets, etc.
using Statistics, LinearAlgebra #covariance and solving systems
using OhMyThreads, ChunkSplitters #parallelization
using OhMyThreads: TaskLocalValue
using BangBang #update immutable operator properties
using BitIntegers #Lightening fast bit operations for smallish graphs (less than 1024 nodes)

include("LRU.jl")
include("CustomPairIterators.jl")
include("GraphDataStructure.jl")
include("GraphAlgorithms.jl")
include("Operators.jl")
include("ValidityTests.jl")
include("Score.jl")
include("MainAlgorithm.jl")

#Small helper functions
powerset(x) = Iterators.flatten(subsets(x, i) for i in 0:length(x))
adjacency_matrix(g) = BitMatrix(isAncestor(g, x, y) for x in vertices(g), y in vertices(g))


function getUIntType(n::Int)

    UINT_TYPES = (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512, UInt1024)

    for T in UINT_TYPES
        8 * sizeof(T) ≥ n && return T
    end
end



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
    meekRules!,
    isPotentialSink,
    PDAGtoDAG,
    topologicalSort,
    DAGtoCPDAG,
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
    insertCandidates,
    precheckValidInsert

end
