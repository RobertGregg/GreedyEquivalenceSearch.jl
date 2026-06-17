using GreedyEquivalenceSearch, DataStructures, SmallCollections
using CSV, DataFrames
using Printf


dataID = @sprintf("%04d", 1)
data = CSV.read("test/javaCompare/simulatedDAGs/dag_data_$(dataID).csv", DataFrame) |> Matrix
gJulia = XGES0(data; verbose=true)
@benchmark XGES0($data)
@profview XGES0(data)






data = rand(100,10)
stats = SufficientStats(data; penalty=1.0)
g = Graph(stats.variablesCount; maxDegree=16)
setType =  eltype(g.parents)

score = CachedScore(stats, setType)


∅ = setType()

operatorSet = SortedSet{Operator{setType}, Base.Order.ReverseOrdering}(
    Base.Order.ReverseOrdering(),
    InsertOperator(g, x, y, ∅, score) for (x, y) in allPermutationPairs(vertices(g))
)

bestOperator = popfirst!(operatorSet)

isValid(g, bestOperator)

bestOperator.scoreDelta > 0
applyOperator(g, bestOperator, operatorSet, score)

operatorSet