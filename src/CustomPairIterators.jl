"""
    CombinationPairs(n::Int)

An efficient, memory-mapped `AbstractVector` representing all unique 2-combinations 
of indices from `1` to `n`.

Elements are returned as `Tuple{Int, Int}` in lexicographical order `(i, j)` such that 
`1 ≤ i < j ≤ n`. The total length of the vector is `binomial(n, 2)`.

# Fields
- `n::Int`: The upper bound of the index pool.

# Examples
```julia
julia> pairs = CombinationPairs(4);

julia> length(pairs)
6

julia> pairs[1]
(1, 2)

julia> pairs[4]  # The beginning of the second row (i=2)
(2, 3)

julia> collect(pairs)
6-element Vector{Tuple{Int, Int}}:
 (1, 2)
 (1, 3)
 (1, 4)
 (2, 3)
 (2, 4)
 (3, 4)
```
"""
struct CombinationPairs <: AbstractVector{Tuple{Int,Int}}
    n::Int
end

Base.size(P::CombinationPairs) = (P.n * (P.n - 1) ÷ 2,)
Base.IndexStyle(::Type{<:CombinationPairs}) = IndexLinear()
ChunkSplitters.is_chunkable(::CombinationPairs) = true


function Base.getindex(P::CombinationPairs, k::Int)
    n = P.n
    N = length(P)

    # m is the number of rows remaining below row i
    # This is the integer solution to: m(m+1)/2 <= k_rev
    m = (isqrt(1 + 8 * (N - k)) - 1) ÷ 2

    # Calculate i (1-based row index)
    i = n - 1 - m

    # Calculate how many pairs exist before row i
    # Sum of (n-1) + (n-2) + ... + (n-(i-1))
    pairs_before_i = (i - 1) * n - (i * (i - 1)) ÷ 2

    # j is the offset within the current row
    j = i + (k - pairs_before_i)

    return (i, j)
end


Base.iterate(P::CombinationPairs) = begin
    P.n ≤ 1 && return nothing
    # State: (stateᵢ, stateⱼ, index)
    # We need initialStateⱼ to reset j's position when i advances
    return ((1, 2), (1, 2, 1))
end

function Base.iterate(P::CombinationPairs, state)

    (stateᵢ, stateⱼ, index) = state

    index == length(P) && return nothing

    if stateⱼ < P.n
        return ((stateᵢ, stateⱼ + 1), (stateᵢ, stateⱼ + 1, index + 1))
    end

    return ((stateᵢ + 1, stateᵢ + 2), (stateᵢ + 1, stateᵢ + 2, index + 1))
end



"""
    PermutationPairs(n::Int)

An efficient, memory-mapped `AbstractVector` representing all 2-permutations 
of indices from `1` to `n`.

Elements are returned as `Tuple{Int, Int}` in row-major order `(i, j)` such that 
`1 ≤ i ≤ n`, `1 ≤ j ≤ n`, and `i ≠ j` (the diagonal is skipped). The total length 
of the vector is `n * (n - 1)`.

# Fields
- `n::Int`: The upper bound of the index pool.

# Examples
```julia
julia> perms = PermutationPairs(3);

julia> length(perms)
6

julia> perms[1]
(1, 2)

julia> perms[3]  # Start of the second row (skips 1,1)
(2, 1)

julia> collect(perms)
6-element Vector{Tuple{Int, Int}}:
 (1, 2)
 (1, 3)
 (2, 1)
 (2, 3)
 (3, 1)
 (3, 2)
```
"""
struct PermutationPairs <: AbstractVector{Tuple{Int,Int}}
    n::Int
end

# Total number of permutation pairs is n * (n - 1)
Base.size(P::PermutationPairs) = (P.n * (P.n - 1),)
Base.IndexStyle(::Type{<:PermutationPairs}) = IndexLinear()
ChunkSplitters.is_chunkable(::PermutationPairs) = true

# Helper to get a specific pair from a linear index k
function Base.getindex(p::PermutationPairs, k::Int)
    n = p.n

    # Convert to 0-based index for easier division/modulo arithmetic
    k0 = k - 1

    # Because every row has exactly (n - 1) elements:
    # i is determined by which chunk of (n - 1) the index falls into.
    i = (k0 ÷ (n - 1)) + 1

    # j_offset is the 1-based position within that specific row chunk
    j_offset = (k0 % (n - 1)) + 1

    # To find the actual j value, we must skip the diagonal where i == j.
    # If our offset pushes us to or past the row index i, we simply add 1.
    j = j_offset ≥ i ? j_offset + 1 : j_offset

    return (i, j)
end

Base.iterate(P::PermutationPairs) = begin
    P.n ≤ 1 && return nothing
    # State: (stateᵢ, stateⱼ, index)
    # We need initialStateⱼ to reset j's position when i advances
    return ((1, 2), (1, 2, 1))
end

function Base.iterate(P::PermutationPairs, state)

    (stateᵢ, stateⱼ, index) = state

    index == length(P) && return nothing

    if stateⱼ < P.n
        newStateⱼ = stateⱼ + 1
        if newStateⱼ == stateᵢ
            newStateⱼ += 1
            return ((stateᵢ, newStateⱼ), (stateᵢ, newStateⱼ, index + 1))
        end
        return ((stateᵢ, newStateⱼ), (stateᵢ, newStateⱼ, index + 1))
    end

    return ((stateᵢ + 1, 1), (stateᵢ + 1, 1, index + 1))
end

#Iterators that use the struct defined above
allCombinationPairs(v::AbstractVector) = ((v[i], v[j]) for (i, j) in CombinationPairs(length(v)))

allPermutationPairs(v::AbstractVector) = ((v[i], v[j]) for (i, j) in PermutationPairs(length(v)))


#Generic one-liners that will work for pretty much anything else that can be iterated 
allCombinationPairs(v) = ((x, y) for (i, x) in enumerate(v) for y in Iterators.drop(v, i))
allPermutationPairs(v) = ((x, y) for x in v for y in v if x ≠ y)
