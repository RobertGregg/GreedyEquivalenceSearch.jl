using GreedyEquivalenceSearch
using CSV, DataFrames
using Printf
using CairoMakie, AlgebraOfGraphics

dataID = @sprintf("%04d", 11)
df = CSV.read("test/javaCompare/simulatedDAGs/dag_data_$(dataID).csv", DataFrame)
gJulia = ges(df; verbose=true)
@benchmark ges($df)
@profview ges(df)

redirect_stdio(stdout="output.log") do
    ges(df; verbose=true)
end

df = CSV.read("test/javaCompare/simulatedDAGs/large_sim_data.csv", DataFrame)
gJulia = ges(df; verbose=true)



######################################################
# Benchmark Eslapsed time
######################################################


function gettimes()

    timesJulia = Float64[]
    timesJava = Float64[]

    for i in 1:36
        dataID = @sprintf("%04d", i)
        df = CSV.read("test/javaCompare/simulatedDAGs/dag_data_$(dataID).csv", DataFrame) |> Matrix
        benchmark = @benchmark ges($df;)
        medianTime = median(benchmark.times) / 1e9
        @show (i, medianTime)
        push!(timesJulia, medianTime)


        javaFilepath = "test/javaCompare/fges_outputs/output_$(dataID).stdout.txt"
        javaResult = filter(line -> occursin("Elapsed time", line), readlines(open(javaFilepath)))
        push!(timesJava, parse(Float64, match(r"[\d.]+", first(javaResult)).match))
    end

    return timesJulia, timesJava
end


timesJulia, timesJava = gettimes()

fig_time = Figure()
ax = Axis(fig_time[1, 1],
    xlabel = "Julia Times (s)",
    ylabel="Java Times (s)",
     title="Elaspsed Times for FGES",
    limits = (0,2, 0, 2)) 
scatter!(ax, timesJulia, timesJava)
ablines!(0, 1; color = :red, linestyle = :dash)
text!(ax, 1.95,0.05, text = "Above line Julia faster\nBelow line Java Faster",
    align = (:right, :bottom) )
fig_time

save("test/javaCompare/results/timing.png", fig_time)


######################################################
# Correctness Measurements
######################################################


#Calculate precision and recall for edge recovery
function contingencyTable(g, gTrue)

    continTable = zeros(Int, 2, 2)

    for (x, y) in allCombinationPairs(vertices(gTrue))
        trueEdge = isAdjacent(gTrue, x, y)
        estEdge = isAdjacent(g, x, y)

        if trueEdge & estEdge #true positive
            continTable[1, 1] += 1
        elseif !trueEdge & !estEdge #true negative
            continTable[2, 2] += 1
        elseif !trueEdge & estEdge #false positive
            continTable[2, 1] += 1
        else #false negative
            continTable[1, 2] += 1
        end
    end

    return continTable
end

modelPrecision(continTable) = continTable[1, 1] / sum(continTable[:, 1])
modelRecall(continTable) = continTable[1, 1] / sum(continTable[1, :])


function runComparisons(id; verbose=true)

    dataID = @sprintf("%04d", id)

    println("running DAG $id")

    ##################
    # Julia
    ##################

    df = CSV.read("test/javaCompare/simulatedDAGs/dag_data_$(dataID).csv", DataFrame)

    gJulia = ges(df; verbose=verbose)

    ##################
    # Java
    ##################

    gJava = Graph(size(df, 2))
    javaFilepath = "test/javaCompare/fges_outputs/output_$(dataID)_out.txt"

    javaResult = filter(line -> occursin(r"\"X\d+\" \D{3} \"X\d+\"", line), readlines(open(javaFilepath)))
    javaResult = split.(javaResult, " ")

    javaEdges = [parse.(Int, filter.(isdigit, line[[2, 4]])) for line in javaResult]

    for (i, edge) in enumerate(javaEdges)

        addEdge!(gJava, edge..., directed=javaResult[i][3] == "-->")

    end

    ##################
    # True Graph
    ##################

    gTrue = Graph(size(df, 2); maxDegree=32)
    simEdges = CSV.read("test/javaCompare/simulatedDAGs/dag_graph_$(dataID).csv", DataFrame) |> Matrix

    if size(simEdges, 2) == 1
        simEdges = reduce(vcat, split.(simEdges, " ") |> x -> permutedims.(x))
    end


    for i in axes(simEdges, 1)
        nodes = parse.(Int, filter.(isdigit, simEdges[i, [1, 3]]))
        addEdge!(gTrue, nodes...)
    end

    continTableJulia = contingencyTable(gJulia, gTrue)
    juliaPrecision = modelPrecision(continTableJulia)
    juliaRecall = modelRecall(continTableJulia)
    juliaF1 = 2 * (juliaPrecision * juliaRecall) / (juliaPrecision + juliaRecall)
    juliaHamming = sum(adjacency_matrix(gJulia) .≠ adjacency_matrix(gTrue))


    continTableJava = contingencyTable(gJava, gTrue)
    javaPrecision = modelPrecision(continTableJava)
    javaRecall = modelRecall(continTableJava)
    javaF1 = 2 * (javaPrecision * javaRecall) / (javaPrecision + javaRecall)
    javaHamming = sum(adjacency_matrix(gJava) .≠ adjacency_matrix(gTrue))

    return (
            id = id,
            language = "julia",
            precision = juliaPrecision,
            recall = juliaRecall,
            f1 = juliaF1,
            hamming = juliaHamming
        ), 
        (
            id = id,
            language = "java",
            precision = javaPrecision,
            recall = javaRecall,
            f1 = javaF1,
            hamming = javaHamming
        )
end


# Preallocate the DataFrame with typed columns
results = DataFrame(
    id=Int[],
    language=String[],
    precision=Float64[],
    recall=Float64[],
    f1=Float64[],
    hamming=Int[],
)

for id in 1:36
    julia_metrics, java_metrics = runComparisons(id; verbose=false)

    push!(results, julia_metrics)
    push!(results, java_metrics)
end



results_long = stack(
    results,
    [:precision, :recall, :f1],
    [:id, :language, :hamming];
    variable_name = :metric,
    value_name = :value
)


results_diff = combine(groupby(results, :id)) do g
    j = g[g.language .== "julia", :]
    ja = g[g.language .== "java", :]

    (; id = g.id[1],
      precision_diff = j.precision[1] - ja.precision[1],
      recall_diff    = j.recall[1]    - ja.recall[1],
      f1_diff        = j.f1[1]        - ja.f1[1],
      hamming_diff   = ja.hamming[1]   - j.hamming[1]) #this is flipped ebcause lower hamming is better
end


results_long_diff = stack(
    results_diff,
    [:precision_diff, :recall_diff, :f1_diff, :hamming_diff],
    [:id];
    variable_name = :metric,
    value_name = :value
)

results_long_diff.metric_sign = @. ifelse(results_long_diff.value > 0, "Julia Better","Java Better")


#Precision, Recall, F1 Summary Boxplot
fig_metric_summary = data(results_long) * visual(BoxPlot) *
    mapping(:metric, :value, color=:language, dodge=:language) |> draw


save("test/javaCompare/results/metric_summary.png", fig_metric_summary)    

#Precision, Recall, F1 Differences per ID
fig_metric_differences = data(results_long_diff) * visual(BarPlot) *
    mapping(:id, :value => "Metric Difference",
    color=:metric_sign => "Language",
    layout=:metric => renamer("recall_diff" => "Recall", "precision_diff" => "Precision", "f1_diff" => "F1", "hamming_diff" => "Hamming")) |>
    draw(facet=(; linkyaxes=:none), legend = (; position = :bottom))

save("test/javaCompare/results/metric_differences.png", fig_metric_differences) 

#Detailed comparison between Hamming Distances
hammingJulia = subset(results, :language => ByRow(x -> x == "julia")).hamming
hammingJava = subset(results, :language => ByRow(x -> x == "java")).hamming
fig_hamming = Figure()
ax = Axis(fig_hamming[1, 1],
xlabel = "Julia Hamming Distance",
ylabel="Java Hamming Distance",
limits = (0,500, 0,500)) 
scatter!(ax, hammingJulia, hammingJava)
ablines!(0, 1; color = :red, linestyle = :dash)
text!(ax, 490,10, text = "Above line Julia Better\nBelow line Java Better",
align = (:right, :bottom) )
fig_hamming

save("test/javaCompare/results/hamming.png", fig_hamming) 