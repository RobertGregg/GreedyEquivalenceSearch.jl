using SmallCollections

struct BitEncoder
    tobit::Dict{Int,Int}
    frombit::SmallSet{16,Int}
end


function BitEncoder(universe)

    # u = collect(universe)

    length(universe) <= 64 || error("Universe too large")

    tobit = Dict{Int,Int}()

    for (i, x) in enumerate(universe)
        tobit[x] = i - 1
    end

    return BitEncoder(tobit, universe)
end


function encode(enc::BitEncoder, xs)
    m = UInt64(0)

    for x in xs
        bit = enc.tobit[x]
        m |= UInt64(1) << bit
    end

    return m
end


function decode(enc::BitEncoder, m::UInt64)

    xs = Int[]

    for (i, x) in enumerate(enc.frombit)

        if (m & (UInt64(1) << (i - 1))) != 0
            push!(xs, x)
        end
    end

    return xs
end

# Convert a set of integers in 1:64 to a UInt64 mask
function mask(xs)
    m = UInt64(0)
    for x in xs
        m |= UInt64(1) << (x - 1)
    end
    return m
end

# Convert back for debugging
function unmask(m::UInt64)
    xs = Int[]
    for i in 1:64
        if (m & (UInt64(1) << (i - 1))) != 0
            push!(xs, i)
        end
    end
    return xs
end


invalid = UInt64[]

push!(invalid, mask([1,2]))
push!(invalid, mask([3,4]))


function should_prune(candidate::UInt64, invalids)
    for bad in invalids
        if (candidate & bad) == bad
            return true
        end
    end
    return false
end


x = mask([1,2,4])

should_prune(x, invalid)  # true


function add_invalid!(invalids, newbad)

    # already implied
    for bad in invalids
        if (newbad & bad) == bad
            return
        end
    end

    # remove supersets
    filter!(bad -> !((bad & newbad) == newbad), invalids)

    push!(invalids, newbad)
end



s = SmallSet{16}([1,5,33,999])

enc = BitEncoder(s)

a = encode(enc, [1, 5])
b = encode(enc, [1, 5, 999])

(a & b) == a
# true