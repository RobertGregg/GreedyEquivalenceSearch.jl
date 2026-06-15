module GreedyEquivalenceSearchDataFramesExt

import GreedyEquivalenceSearch: ges #To extend methods
using GreedyEquivalenceSearch, DataFrames

#Try to convert data to matrix (e.g., a DataFrame)
ges(data::DataFrame; verbose=false, maxDegree=16, penalty=1.0) = ges(Matrix(data); verbose, maxDegree, penalty)

end


