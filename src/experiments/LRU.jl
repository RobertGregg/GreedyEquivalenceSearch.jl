# ================================================================
#  lru_cache.jl — Efficient LRU Cache in Julia
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
#   put!     →  O(1)  (eviction also O(1))
#   delete!  →  O(1)
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

All three core operations — `get`, `put!`, and `delete!` — run in **O(1)** time
by pairing a `Dict` (O(1) lookup) with a doubly-linked list (O(1) reordering).

## Constructors
```julia
LRUCache{String,Int}(4)   # typed cache, capacity 4
LRUCache(4)                # untyped LRUCache{Any,Any}
```

## Example
```julia
c = LRUCache{String,Int}(3)
put!(c, "a", 1); put!(c, "b", 2); put!(c, "c", 3)
get(c, "a", -1)    # → 1  ("a" now MRU)
put!(c, "d", 4)    # "b" evicted (was LRU)
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

    function LRUCache{K,V}(cap::Int) where {K,V}
        cap ≥ 1 || throw(ArgumentError("capacity must be ≥ 1 (got $cap)"))
        new{K,V}(cap, 0, Dict{K, Node{K,V}}(), nothing, nothing)
    end
end

# Convenience untyped constructor
LRUCache(cap::Int) = LRUCache{Any,Any}(cap)


# ── Trait extensions ──────────────────────────────────────────────

Base.length(c::LRUCache)      = c.size
Base.isempty(c::LRUCache)     = c.size == 0
Base.haskey(c::LRUCache, key) = haskey(c.map, key)


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
    n = get(c.map, key, nothing)
    isnothing(n) && return default
    _touch!(c, n)
    n.val
end

"""
    put!(cache, key, val) → cache

Insert or update `key ↦ val`, marking it as MRU.
When the cache is at capacity a new insertion silently evicts the LRU entry.
Updating an existing key never triggers eviction.
"""
function put!(c::LRUCache{K,V}, key::K, val::V) where {K,V}
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
    c
end

"""
    delete!(cache, key) → cache

Remove `key` from the cache if present; no-op otherwise.
"""
function Base.delete!(c::LRUCache{K,V}, key) where {K,V}
    n = get(c.map, key, nothing)
    isnothing(n) && return c
    _unlink!(c, n)
    delete!(c.map, key)
    c.size -= 1
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
"""
function Base.get!(f::Function, c::LRUCache{K,V}, key::K) where {K,V}
    n = get(c.map, key, nothing)
    if !isnothing(n)
        _touch!(c, n)
        return n.val
    end
    val = convert(V, f())
    put!(c, key, val)
    val
end

# Bracket read: cache[key]
function Base.getindex(c::LRUCache{K,V}, key::K) where {K,V}
    v = get(c, key, nothing)
    isnothing(v) && throw(KeyError(key))
    v
end

# Bracket write: cache[key] = val
Base.setindex!(c::LRUCache{K,V}, val::V, key::K) where {K,V} = put!(c, key, val)

"""
    collect(cache) → Vector{Pair{K,V}}

Return a snapshot of all entries in MRU → LRU order.
This does **not** modify any recency information.
"""
function Base.collect(c::LRUCache{K,V}) where {K,V}
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

const _SHOW_LIMIT = 20    # match Base Dict truncation threshold

function Base.show(io::IO, c::LRUCache{K,V}) where {K,V}
    n = c.size
    print(io, "LRUCache{$K, $V}(capacity = $(c.capacity)) with $n ",
              n == 1 ? "entry" : "entries")
    n == 0 && return
    print(io, ":")
    truncated = n > _SHOW_LIMIT
    limit     = truncated ? _SHOW_LIMIT : n
    cur       = c.head
    for i in 1:limit
        print(io, "\n  ", repr(cur.key), " => ", repr(cur.val))
        i == 1           && print(io, "  # MRU")
        i == n && !truncated && print(io, "  # LRU")
        cur = cur.next
    end
    if truncated
        print(io, "\n  ⋮")
        print(io, "\n  ($(n - _SHOW_LIMIT) entries not shown, LRU = ",
                  repr(c.tail.key), ")")
    end
end