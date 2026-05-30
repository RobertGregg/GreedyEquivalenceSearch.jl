using GreedyEquivalenceSearch
using Test
using CSV, DataFrames
using SmallCollections


@testset "GraphDataStructure" begin
    include("test_GraphDataStructure.jl")
end

@testset "Operators" begin
    include("test_Operators.jl")
end

@testset "GraphAlgorithms" begin
    include("test_GraphAlgorithms.jl")
end


@testset "Powerset Iterator" begin
    function test_powerset(x)
        s = 0
    
        for xᵢ in powerset(x)
            s += length(xᵢ)
        end
        return s
    end

    s = SmallSet{16}([1,3,5])

    @test test_powerset(s) == 12
end




@testset "Loading Data" begin
    data = CSV.read("data/rCausalMGM_sim_data.csv",DataFrame) |> Matrix
    @test data isa Matrix
end

data = CSV.read("test/data/rCausalMGM_sim_data.csv",DataFrame) |> Matrix

gJulia = ges(data; verbose=true)


#Read and parse the java results
gJava = Graph(size(data,2))
javaFilepath = "test/data/features50_observations1000_out.txt"

javaResult = filter(line -> occursin(r"\"X\d+\" \D{3} \"X\d+\"",line), readlines(open(javaFilepath)))
javaResult = split.(javaResult," ")

javaEdges = [parse.(Int, filter.(isdigit, line[[2,4]])) for line in javaResult]

for (i,edge) in enumerate(javaEdges)

    addEdge!(gJava,edge..., directed = javaResult[i][3] == "-->")

end

#Generate the true graph
gTrue = Graph(size(data,2))

simEdges = CSV.read("test/data/rCausalMGM_sim_graph.csv",DataFrame) |> Matrix

for i in axes(simEdges,1)
    nodes = parse.(Int, filter.(isdigit,simEdges[i,[1,3]]))
    addEdge!(gTrue,nodes...)
end


#Calculate precision and recall
function contingencyTable(g,gTrue)

    continTable = zeros(Int,2,2)

    for (x,y) in allCombinationPairs(vertices(gTrue))
        trueEdge = isAdjacent(gTrue,x,y)
        estEdge = isAdjacent(g,x,y)

        if trueEdge & estEdge #true positive
            continTable[1,1] += 1
        elseif !trueEdge & !estEdge #true negative
            continTable[2,2] += 1
        elseif !trueEdge & estEdge #false positive
            continTable[2,1] += 1
        else #false negative
            continTable[1,2] += 1
        end
    end

    return continTable
end

modelPrecision(continTable) = continTable[1,1] / sum(continTable[:,1])
modelRecall(continTable) = continTable[1,1] / sum(continTable[1,:])


continTableJulia = contingencyTable(g,gTrue)
modelPrecision(continTableJulia)
modelRecall(continTableJulia)


continTableJava = contingencyTable(gJava,gTrue)
modelPrecision(continTableJava)
modelRecall(continTableJava)

sum(adjacency_matrix(gJulia) .≠ adjacency_matrix(gTrue))
sum(adjacency_matrix(gJava) .≠ adjacency_matrix(gTrue))

using Plots

heatmap(adjacency_matrix(gTrue), title="True")
heatmap(adjacency_matrix(gJulia), title="Julia")
heatmap(adjacency_matrix(gJava), title="Java")