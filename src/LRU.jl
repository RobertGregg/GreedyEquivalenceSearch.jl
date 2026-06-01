# ================================================================
# LRU.jl — Efficient LRU Cache in Julia
# ================================================================
#
#  Internal layout
#  ───────────────
#   Dict{K, Node}   →  O(1) key lookup
#   Doubly-linked list  →  O(1) recency maintenance
#
#   head (front) = Most Recently Used   (MRU)
#   tail (back)  = Least Recently Used  (LRU)
#
#   ┌────────┐ next ┌────────┐ next     ┌────────┐
#   │  head  │─────►│  ...   │─────►··· │  tail  │
#   │ (MRU)  │◄─────│        │◄─────··· │ (LRU)  │
#   └────────┘ prev └────────┘          └────────┘
#
#  Complexity
#  ──────────
#   get      →  O(1)
#   get!     →  O(1)
#   place!   →  O(1)  (eviction also O(1))
#   delete!  →  O(1)
#
#  Thread safety
#  ─────────────
#   Every public method acquires a ReentrantLock before touching shared state.
#   get! calls its factory f() inside the lock → exactly-once-per-miss semantics:
#   two threads racing on the same absent key serialize; only one computes.
#   show snapshots the list under the lock then prints outside it.
# ================================================================


# ── Node ─────────────────────────────────────────────────────────

mutable struct Node{K,V}
    key  :: K
    val  :: V
    prev :: Union{Node{K,V}, Nothing}
    next :: Union{Node{K,V}, Nothing}

    Node{K,V}(k::K, v::V) where {K,V} = new{K,V}(k, v, nothing, nothing)
end


# ── LRUCache ──────────────────────────────────────────────────────

"""
    LRUCache{K,V}(capacity::Int)

A parametric, fixed-capacity Least-Recently-Used cache.

All three core operations — `get`, `place!`, and `delete!` — run in **O(1)** time
by pairing a `Dict` (O(1) lookup) with a doubly-linked list (O(1) reordering).

## Constructors
```julia
LRUCache{String,Int}(4)   # typed cache, capacity 4
LRUCache(4)                # untyped LRUCache{Any,Any}
```

## Thread Safety
All operations are protected by an internal `ReentrantLock`. The cache is safe
to share across `Threads.@spawn` tasks without any external synchronization.
`get!` calls its factory function *inside* the lock, so two threads racing on the
same absent key will serialize — only one computes the value, the other gets it
from the cache. If your factory is long-running and you prefer optimistic
(compute-outside-lock) semantics, compute the value first and use `place!` instead.
```julia
c = LRUCache{String,Int}(3)
place!(c, "a", 1); place!(c, "b", 2); place!(c, "c", 3)
get(c, "a", -1)    # → 1  ("a" now MRU)
place!(c, "d", 4)    # "b" evicted (was LRU)
haskey(c, "b")     # → false
c["c"]             # → 99 (bracket syntax)
```
"""
mutable struct LRUCache{K,V}
    capacity :: Int
    size     :: Int
    map      :: Dict{K, Node{K,V}}
    head     :: Union{Node{K,V}, Nothing}   # MRU end
    tail     :: Union{Node{K,V}, Nothing}   # LRU end
    lock     :: ReentrantLock               # guards all mutable state

    function LRUCache{K,V}(cap::Int) where {K,V}
        cap ≥ 1 || throw(ArgumentError("capacity must be ≥ 1 (got $cap)"))
        new{K,V}(cap, 0, Dict{K, Node{K,V}}(), nothing, nothing, ReentrantLock())
    end
end

# Convenience untyped constructor
LRUCache(cap::Int) = LRUCache{Any,Any}(cap)


# ── Trait extensions ──────────────────────────────────────────────

Base.length(c::LRUCache)      = lock(c.lock) do; c.size; end
Base.isempty(c::LRUCache)     = lock(c.lock) do; c.size == 0; end
Base.haskey(c::LRUCache, key) = lock(c.lock) do; haskey(c.map, key); end


# ── Private helpers ───────────────────────────────────────────────

# Splice node out of its current list position (does NOT free it).
@inline function _unlink!(c::LRUCache{K,V}, n::Node{K,V}) where {K,V}
    isnothing(n.prev) ? (c.head = n.next)  : (n.prev.next = n.next)
    isnothing(n.next) ? (c.tail = n.prev)  : (n.next.prev = n.prev)
    n.prev = n.next = nothing
end

# Prepend node to the MRU end (head).
@inline function _prepend!(c::LRUCache{K,V}, n::Node{K,V}) where {K,V}
    n.prev = nothing
    n.next = c.head
    isnothing(c.head) ? (c.tail = n) : (c.head.prev = n)
    c.head = n
end

# Mark node as the most-recently-used entry.
@inline function _touch!(c::LRUCache{K,V}, n::Node{K,V}) where {K,V}
    c.head === n && return      # already MRU — nothing to do
    _unlink!(c, n)
    _prepend!(c, n)
end

# Evict the least-recently-used entry (the tail).
@inline function _evict_lru!(c::LRUCache{K,V}) where {K,V}
    lru = c.tail
    isnothing(lru) && return
    _unlink!(c, lru)
    delete!(c.map, lru.key)
    c.size -= 1
end


# ── Public API ────────────────────────────────────────────────────

"""
    get(cache, key[, default]) → value | default

Look up `key` and, if found, promote it to MRU and return its value.
Returns `default` (default: `nothing`) when the key is absent.
"""
function Base.get(c::LRUCache{K,V}, key, default=nothing) where {K,V}
    lock(c.lock) do
        n = get(c.map, key, nothing)
        isnothing(n) && return default
        _touch!(c, n)
        n.val
    end
end

"""
    place!(cache, key, val) → cache

Insert or update `key ↦ val`, marking it as MRU.
When the cache is at capacity a new insertion silently evicts the LRU entry.
Updating an existing key never triggers eviction.
"""
function place!(c::LRUCache{K,V}, key::K, val::V) where {K,V}
    lock(c.lock) do
        n = get(c.map, key, nothing)
        if !isnothing(n)                     # ── update existing entry
            n.val = val
            _touch!(c, n)
        else                                 # ── brand-new entry
            n = Node{K,V}(key, val)
            c.map[key] = n
            _prepend!(c, n)
            c.size += 1
            c.size > c.capacity && _evict_lru!(c)
        end
    end
    c
end

"""
    delete!(cache, key) → cache

Remove `key` from the cache if present; no-op otherwise.
"""
function Base.delete!(c::LRUCache{K,V}, key) where {K,V}
    lock(c.lock) do
        n = get(c.map, key, nothing)
        isnothing(n) && return
        _unlink!(c, n)
        delete!(c.map, key)
        c.size -= 1
    end
    c
end

"""
    get!(f, cache, key) → value

Return the cached value for `key` (promoting it to MRU) if present.
Otherwise call `f()`, store the result under `key`, and return it —
inserting into the cache with the usual eviction rules.

Supports the `do`-block form:

```julia
get!(cache, key) do
    expensive_computation(key)
end
```

`f` is called **inside** the lock, so two threads racing on the same absent key
will serialize: only one computes, the other reads the cached result.
"""
function Base.get!(f::Function, c::LRUCache{K,V}, key::K) where {K,V}
    lock(c.lock) do
        n = get(c.map, key, nothing)
        if !isnothing(n)                         # ── cache hit
            _touch!(c, n)
            return n.val
        end
        val = convert(V, f())                    # ── cache miss: compute
        n   = Node{K,V}(key, val)               #    inline place! logic to avoid
        c.map[key] = n                           #    re-acquiring the lock
        _prepend!(c, n)
        c.size += 1
        c.size > c.capacity && _evict_lru!(c)
        val
    end
end

# Bracket read: cache[key]
function Base.getindex(c::LRUCache{K,V}, key::K) where {K,V}
    lock(c.lock) do
        n = get(c.map, key, nothing)
        isnothing(n) && throw(KeyError(key))
        _touch!(c, n)
        n.val
    end
end

# Bracket write: cache[key] = val
Base.setindex!(c::LRUCache{K,V}, val::V, key::K) where {K,V} = place!(c, key, val)

"""
    collect(cache) → Vector{Pair{K,V}}

Return a snapshot of all entries in MRU → LRU order.
This does **not** modify any recency information.
"""
function Base.collect(c::LRUCache{K,V}) where {K,V}
    lock(c.lock) do
        out = Vector{Pair{K,V}}(undef, c.size)
        cur = c.head
        i   = 1
        while !isnothing(cur)
            out[i] = cur.key => cur.val
            cur    = cur.next
            i     += 1
        end
        out
    end
end

const _SHOW_LIMIT = 20    # match Base Dict truncation threshold

function Base.show(io::IO, c::LRUCache{K,V}) where {K,V}
    # Snapshot state under lock — print outside so IO doesn't block other threads.
    n, cap, entries, lru_key = lock(c.lock) do
        snap = Vector{Pair{K,V}}(undef, c.size)
        cur  = c.head
        i    = 1
        while !isnothing(cur)
            snap[i] = cur.key => cur.val
            cur = cur.next
            i  += 1
        end
        lru = isnothing(c.tail) ? nothing : c.tail.key
        c.size, c.capacity, snap, lru
    end

    print(io, "LRUCache{$K, $V}(capacity = $cap) with $n ",
              n == 1 ? "entry" : "entries")
    n == 0 && return
    print(io, ":")
    truncated = n > _SHOW_LIMIT
    limit     = truncated ? _SHOW_LIMIT : n
    for i in 1:limit
        k, v = entries[i]
        print(io, "\n  ", repr(k), " => ", repr(v))
        i == 1           && print(io, "  # MRU")
        i == n && !truncated && print(io, "  # LRU")
    end
    if truncated
        print(io, "\n  ⋮")
        print(io, "\n  ($(n - _SHOW_LIMIT) entries not shown, LRU = ", repr(lru_key), ")")
    end
end


# ================================================================
#  Demo
# ================================================================

function demo()
    println("=" ^ 55)
    println("  LRU Cache Demo")
    println("=" ^ 55)

    # ── Basic insertion & eviction ──────────────────────────────
    println("\n── Capacity-3 cache ──")
    c = LRUCache{String,Int}(3)
    place!(c, "a", 1); place!(c, "b", 2); place!(c, "c", 3)
    println("After inserting a=1, b=2, c=3:")
    println(c)

    println("\nget(\"a\") = ", get(c, "a", -1), "  (\"a\" becomes MRU)")
    println(c)

    println("\nInsert d=4  →  \"b\" evicted (was LRU):")
    place!(c, "d", 4)
    println(c)
    println("  haskey(\"b\") = ", haskey(c, "b"))

    # ── Update existing key ─────────────────────────────────────
    println("\n── Update existing key ──")
    place!(c, "c", 99)
    println("After place!(c, \"c\", 99):")
    println(c)

    # ── get! with do-block ──────────────────────────────────────
    println("\n── get! with do-block ──")
    calls = 0
    for key in ["a", "x", "a", "y", "x"]
        val = get!(c, key) do
            calls += 1
            length(key) * 10          # cheap stand-in for "expensive work"
        end
        println("  get!(c, \"$key\") = $val")
    end
    println("  factory called $calls time(s)  (cache hits avoided recomputation)")
    println(c)

    # ── delete! ─────────────────────────────────────────────────
    println("\n── delete! ──")
    delete!(c, "d")
    println("After delete!(c, \"d\"):")
    println(c)

    # ── Bracket syntax ──────────────────────────────────────────
    println("\n── Bracket syntax ──")
    c["z"] = 7
    println("c[\"z\"] = ", c["z"])
    println(c)

    # ── collect ─────────────────────────────────────────────────
    println("\n── collect (MRU→LRU) ──")
    println("  ", collect(c))

    # ── Miss & default ──────────────────────────────────────────
    println("\n── Cache miss ──")
    println("  get(c, \"x\", -1) = ", get(c, "x", -1))

    # ── Thread-safety demo ──────────────────────────────────────
    println("\n── Thread-safety demo ──")
    println("  (run with: julia -t 4 lru_cache.jl for real parallelism)")
    println("  Threads available: $(Threads.nthreads())")

    # 25 unique keys, capacity 32 → no evictions, so each key is
    # computed exactly once no matter how many threads race on it.
    t_cache        = LRUCache{Int,Int}(32)
    compute_count  = Threads.Atomic{Int}(0)
    results        = Vector{Int}(undef, 120)

    @sync for i in 1:120
        Threads.@spawn begin
            key        = i % 25
            results[i] = get!(t_cache, key) do
                Threads.atomic_add!(compute_count, 1)
                key * key           # stand-in for expensive work
            end
        end
    end

    expected = [(i % 25)^2 for i in 1:120]
    @assert results == expected "Thread-safety violation: incorrect results!"
    println("  All 120 results correct across threads ✓")
    println("  Factory called $(compute_count[])/25 unique key(s) ",
            "($(120 - compute_count[]) cache hits)")
    println(t_cache)

    # ── Metadata ────────────────────────────────────────────────
    println("\n── Metadata ──")
    println("length(c) = ", length(c), "  isempty(c) = ", isempty(c))

    println("\n" * "=" ^ 55)
end
