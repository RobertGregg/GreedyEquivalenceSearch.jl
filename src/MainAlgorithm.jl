

function forwardPhase(g, stats)
    

    #Create a Binary Heap to store valid, scored insert operators. We use a mutable verison to update valid inserts
    validInserts = MutableBinaryMaxHeap{InsertOp}()

    #Initialize valid inserts
    #Note that Insert(X,Y,∅) and Insert(Y,X,∅) result in the same state, so for this initialization we only need to check one
    #Graph is empty so all insert operators will be valid
    ∅ = SmallSet{maxDegree(g),Int}()
    for (x,y) in allPairs(vertices(g))

        scoreDelta = score(stats, y, x) - score(stats, y, ∅)

        push!(validInserts, InsertOperator(x, y, ∅, scoreDelta))
    end

end