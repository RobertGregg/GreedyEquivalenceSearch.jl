####################################################################
# Save/load graphs
####################################################################

"""
    saveGraph(fileName, g,featureNames)

Save the output of fges to a text file. 
"""
function saveGraph(fileName, g, featureNames)
    open(fileName, "w") do io

        for (i, name) in enumerate(featureNames)
            println(io, i, ":", name)
        end

        println(io, "")

        for edge in edges(g)
            println(io, edge)
        end

    end
end

saveGraph(fileName, g) = saveGraph(fileName, g, vertices(g))


"""
    loadGraph(fileName)

Load a saved output of fges from a text file. Outputs both the graph and a list of feature names.
"""
function loadGraph(fileName)

    #Let's check if the node names are numbers or strings
    parseOutput = tryparse(Int, last(split(first(eachline(fileName)), ":")))

    if isnothing(parseOutput)
        nodeNames = String[]
    else
        nodeNames = Int[]
    end

    for line in eachline(fileName)
        if isempty(line)
            break
        end

        if isnothing(parseOutput)
            push!(nodeNames, String(last(split(line, ":"))))
        else
            push!(nodeNames, parse(Int, last(split(line, ":"))))
        end
    end


    #find the largest number in the file
    numFeatures = length(nodeNames)

    g = Graph(numFeatures)

    for line in eachline(fileName)

        sublines = split(line, " ")
        #Check if line was split
        if length(sublines) == 1
            continue
        end


        v₁ = parse(Int, sublines[1])
        v₂ = parse(Int, sublines[3])


        #Check if edge is directed
        directed = sublines[2] == "→"
        addDirectedEdge!(g, v₁, v₂; directed)
    end

    return g, nodeNames
end

####################################################################
# Convert graph to table
####################################################################

#TODO upgrade DataFrames from just an extension
edgetable(g) = DataFrame(edges(g))


function edgetable(g, featureNames)

    df = DataFrame(alledges(g))

    df.parent = featureNames[df.parent]
    df.child = featureNames[df.child]

    return df
end

# Easier syntax for R interface when tuple is used
edgetable(g_featureNames) = edgetable(g_featureNames...)