using GreedyEquivalenceSearch
using CSV, DataFrames


#Calculate precision and recall for edge recovery
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


function runComparison(dataSize; verbose=false)
    
    ##################
    # Julia
    ##################

    data = CSV.read("test/javaCompare/simulatedDAGs/$(dataSize)_sim_data.csv", DataFrame) |> Matrix

    gJulia = ges(data; verbose)

    ##################
    # Java
    ##################

    gJava = Graph(size(data,2))
    javaFilepath = "test/javaCompare/$(dataSize)DAG_out.txt"

    javaResult = filter(line -> occursin(r"\"X\d+\" \D{3} \"X\d+\"",line), readlines(open(javaFilepath)))
    javaResult = split.(javaResult," ")

    javaEdges = [parse.(Int, filter.(isdigit, line[[2,4]])) for line in javaResult]

    for (i,edge) in enumerate(javaEdges)

        addEdge!(gJava,edge..., directed = javaResult[i][3] == "-->")

    end

    ##################
    # True Graph
    ##################

    gTrue = Graph(size(data,2))
    simEdges = CSV.read("test/javaCompare/simulatedDAGs/$(dataSize)_sim_graph.csv",DataFrame) |> Matrix

    if size(simEdges,2) == 1
        simEdges = reduce(vcat, split.(simEdges, " ") |> x -> permutedims.(x))
    end


    for i in axes(simEdges,1)
        nodes = parse.(Int, filter.(isdigit,simEdges[i,[1,3]]))
        addEdge!(gTrue,nodes...)
    end

    continTableJulia = contingencyTable(gJulia,gTrue)
    precision = modelPrecision(continTableJulia)
    recall = modelRecall(continTableJulia)
    f1 = 2*(precision * recall)/(precision + recall)

    @show continTableJulia
    @show (precision, recall, f1)

    println("----------------------------------------------------")

    continTableJava = contingencyTable(gJava,gTrue)
    precision = modelPrecision(continTableJava)
    recall = modelRecall(continTableJava)
    f1 = 2*(precision * recall)/(precision + recall)

    @show continTableJava
    @show (precision, recall, f1)

    return nothing
end


dataSize = "small"
data = CSV.read("test/javaCompare/simulatedDAGs/$(dataSize)_sim_data.csv", DataFrame) |> Matrix

gJulia = ges(data; verbose=true, maxDegree=12)

@benchmark  ges($data)
@profview ges(data; maxDegree=24)