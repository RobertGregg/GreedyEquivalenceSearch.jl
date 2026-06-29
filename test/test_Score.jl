using GreedyEquivalenceSearch
using SmallCollections


data = rand(100, 50)

stats = SufficientStats(data; penalty=1.0)

s =  SmallBitSet{UInt16}()

score = GreedyEquivalenceSearch.CachedScore(stats, typeof(s))

score(5, SmallBitSet{UInt16}(1:3))
score(4, SmallBitSet{UInt16}(1:2))
score(7, SmallBitSet{UInt16}(2:2:10))


node=5
nodeSet =  SmallBitSet{UInt16}(2:2:10)
@benchmark $score($node, $nodeSet)