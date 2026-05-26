using GreedyEquivalenceSearch
using SmallCollections

data = rand(100,50)
data .-= mean(data, dims=1)

stats = SufficientStats(data)

score = GreedyEquivalenceSearch.CachedScore(stats)

score(5, SmallSet{16}(1:3))
score(4, SmallSet{16}(1:2))
score(7, SmallSet{16}(2:2:10))