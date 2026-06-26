module GreedyEquivalenceSearch

using SmallCollections, SmallCombinatorics #for handling set operations, powersets, etc.
using Statistics, LinearAlgebra #covariance and solving systems
using OhMyThreads #parallelization
using BitIntegers #Lightening fast bit operations for smallish graphs (less than 1024 nodes)
using BangBang: setproperties!! #for creating operators with new fields
using ProgressMeter

include("LRU.jl")
include("GraphDataStructure.jl")
include("GraphAlgorithms.jl")
include("Operators.jl")
include("ValidityTests.jl")
include("Score.jl")
include("MainAlgorithm.jl")

#Small helper functions
powerset(x) = Iterators.flatten(subsets(x, i) for i in 0:length(x))
powerset(x::SmallBitSet) = subsets(x)
adjacency_matrix(g) = BitMatrix(isAncestor(g, x, y) for x in vertices(g), y in vertices(g))

#Iterating through pairs
allCombinationPairs(v) = ((x, y) for (i, x) in enumerate(v) for y in Iterators.drop(v, i))
allPermutationPairs(v) = ((x, y) for x in v for y in v if x ≠ y)

function getUIntType(n::Int)

    UINT_TYPES = (UInt8, UInt16, UInt32, UInt64, UInt128, UInt256, UInt512, UInt1024)

    for T in UINT_TYPES
        8 * sizeof(T) ≥ n && return T
    end
end


#Extension functions
function plotNetwork end


#TODO Clean up function exports
export
    #GreedyEquivalenceSearch.jl
    allPermutationPairs,
    allCombinationPairs,
    adjacency_matrix,
    plotNetwork,
    #GraphStructure.jl
    Graph,
    GraphEdge,
    maxDegree,
    vertices,
    nv,
    ne,
    addDirectedEdge!,
    addUndirectedEdge!,
    removeUndirectedEdge!,
    removeDirectedEdge!,
    orientEdge!,
    unorientEdge!,
    reorientEdge!,
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
    edges,
    undirectedEdges,
    directedEdges,
    #GraphAlgorithms.jl
    isClique,
    isBlocked,
    graphVStructure!,
    meekRules!,
    #Operators.jl
    InsertOperator,
    DeleteOperator,
    setT,
    setH,
    setScore,
    #Score.jl
    SufficientStats,
    CachedScore,
    #ValidityTests.jl
    isValid,
    #MainAlgorithm.jl
    ges,
    search,
    getCandidates,
    applyOperator!


end
