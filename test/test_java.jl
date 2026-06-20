using GreedyEquivalenceSearch
using CSV, DataFrames
using Printf

dataID = @sprintf("%04d", 12)
data = CSV.read("test/javaCompare/simulatedDAGs/dag_data_$(dataID).csv", DataFrame)
gJulia = ges(data; verbose=true)
@benchmark ges($data)
@profview ges(data)

redirect_stdio(stdout="output.log") do
    ges(data; verbose=true)
end

data = CSV.read("test/javaCompare/simulatedDAGs/large_sim_data.csv", DataFrame)
gJulia = ges(data; verbose=true)

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

    data = CSV.read("test/javaCompare/simulatedDAGs/dag_data_$(dataID).csv", DataFrame)

    gJulia = ges(data; verbose=verbose)

    ##################
    # Java
    ##################

    gJava = Graph(size(data, 2))
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

    gTrue = Graph(size(data, 2); maxDegree=32)
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


using TidierPlots


results_long = stack(
    results,
    [:precision, :recall, :f1],
    [:id, :language, :hamming];
    variable_name = :metric,
    value_name = :value
)


ggplot(results_long, aes(x = :metric, y = :value, fill=:language)) +
    geom_boxplot() +
    theme_minimal() +
    labs(
        title = "FGES: Java vs Julia",
        x = "Metric",
        y = "Metric Value")


ggplot(results, aes(x=:id, y=:hamming, fill=:language)) +
    geom_col(position="dodge", gap=0.3) +
    theme_minimal()




ids = results.id

java_color = RGB(0.20, 0.45, 0.75);   # steel blue
julia_color = RGB(0.85, 0.33, 0.25);   # julia red

metrics = [
    ("Precision", results.java_prec, results.julia_prec),
    ("Recall", results.java_rec, results.julia_rec),
    ("F1 Score", results.java_f1, results.julia_f1),
]


# =============================================================================
# 2. Distribution comparison (box plots for overall summary)
# =============================================================================

metric_labels = repeat(["Precision", "Recall", "F1"], inner=nrow(results))
java_vals_all = vcat(results.java_prec, results.java_rec, results.java_f1)
julia_vals_all = vcat(results.julia_prec, results.julia_rec, results.julia_f1)


all_vals = vcat(java_vals_all, julia_vals_all)
all_metrics = vcat(metric_labels, metric_labels)
all_methods = vcat(fill("Java", length(java_vals_all)), fill("Julia", length(julia_vals_all)))

p2 = groupedboxplot(all_metrics, all_vals,
    group=all_methods,
    color=[java_color julia_color],
    alpha=0.75,
    ylabel="Score",
    ylims=(0, 1),
    grid=true,
    gridalpha=0.3,
    legend=:bottomright,
    title="FGES: Java vs Julia — Score Distributions",
    titlefont=font(12, "Helvetica"),
    size=(700, 450),
)

savefig(p2, "test/javaCompare/results/comparison_distributions.png")

# =============================================================================
# 3. Difference plot  (Julia − Java, per metric)
# =============================================================================

diff_plots = map(metrics) do (label, java_vals, julia_vals)
    diffs = julia_vals .- java_vals
    colors = [d >= 0 ? julia_color : java_color for d in diffs]

    bar(ids, diffs,
        label="Julia − Java",
        color=colors,
        alpha=0.8,
        linewidth=0,
        title=label,
        xlabel="Dataset ID",
        ylabel="Δ $(label)",
        legend=false,
        grid=true,
        gridalpha=0.3,
        titlefont=font(12, "Helvetica"),
        tickfont=font(9),
    )
    hline!([0], color=:black, lw=1.5, linestyle=:dash, label=nothing)
end

p3 = plot(diff_plots...,
    layout=(3, 1),
    size=(850, 750),
    plot_title="FGES: Julia − Java (positive = Julia better)",
    left_margin=8Plots.mm,
    bottom_margin=5Plots.mm,
)
savefig(p3, "test/javaCompare/results/comparison_difference.png")



# =============================================================================
# 4. Hamming Distance  (lower = better, no fixed y-axis)
# =============================================================================

ham_diff = results.julia_ham .- results.java_ham
diff_colors = [d <= 0 ? julia_color : java_color for d in ham_diff];

p_ham1 = scatter(ids, results.java_ham,
    label="Java",
    color=java_color,
    lw=2,
    markershape=:circle,
    markersize=5,
    markeralpha=0.8,
)
scatter!(ids, results.julia_ham,
    label="Julia",
    color=julia_color,
    lw=2,
    markershape=:diamond,
    markersize=5,
    markeralpha=0.8,
    xlims=(0, 40),
    title="Hamming Distance per Dataset",
    xlabel="Dataset ID",
    ylabel="Hamming Distance",
    grid=true,
    gridalpha=0.3,
    legend=:topleft,
    titlefont=font(12, "Helvetica"),
    tickfont=font(9),
)

p_ham2 = bar(ids, ham_diff,
    color=diff_colors,
    alpha=0.8,
    linewidth=0,
    label=false,
    xlims=(0, 40),
    title="Difference (Julia − Java)",
    xlabel="Dataset ID",
    ylabel="ΔHamming",
    grid=true,
    gridalpha=0.3,
    titlefont=font(12, "Helvetica"),
    tickfont=font(9),
)
hline!([0], color=:black, lw=1.5, linestyle=:dash, label=nothing)
annotate!(maximum(ids) * 0.8, maximum(ham_diff) * 0.9,
    text("red = Julia better\nblue = Java better", 8, :right, :darkgray))

p_ham = plot(p_ham1, p_ham2,
    layout=(2, 1),
    size=(850, 550),
    plot_title="FGES: Hamming Distance — Java vs Julia",
    left_margin=8Plots.mm,
    bottom_margin=5Plots.mm,
)
savefig(p_ham, "test/javaCompare/results/comparison_hamming.png")


######################################################
# Benchmark Eslapsed time
######################################################


function gettimes()

    timesJulia = Float64[]
    timesJava = Float64[]

    for i in 1:36
        dataID = @sprintf("%04d", i)
        data = CSV.read("test/javaCompare/simulatedDAGs/dag_data_$(dataID).csv", DataFrame) |> Matrix
        benchmark = @benchmark ges($data;)
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



plot(timesJulia, timesJava,
    seriestype=:scatter,
    xlabel="Julia Times (s)",
    ylabel="Java Times (s)",
    title="Elaspsed Times for FGES",
    # xlims = (0,1.7),
    # ylims = (0,1.7),
    legend=:none,
    framestyle=:box
)

# 3. Add the identity line (y = x) using the plot limits
# Using standard identity function syntax: plot!(identity, min, max)
plot!(identity, 0, 1.5,
    line=:dash,
    color=:red,
)
annotate!(1.5, 0.1, text("Above line Julia faster\nBelow line Java Faster", :right, 10))

savefig("test/javaCompare/results/comparison_timing.png")
