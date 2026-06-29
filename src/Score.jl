####################################################################
# Precomputed statisitics for scoring
####################################################################

"""
Pre-computed sufficient statistics for Gaussian BIC.
Stores the covariance matrix, sample size, and feature count.
"""
struct SufficientStats{F<:AbstractFloat,T<:AbstractMatrix{F}}
    covariance::T
    observationsCount::Int
    variablesCount::Int
    penalty::F
end


function SufficientStats(data; penalty)

    #Computes the covariance matrix of the mean centered features
    #corrected=false divides by n instead of n-1
    #dim=1 mean centers the columns before computing covariance
    covariance = cov(data, dims=1, corrected=false)
    observationsCount, variablesCount = size(data)

    return SufficientStats(covariance, observationsCount, variablesCount, penalty)
end

####################################################################
# Calculate Mean Square Error (MSE) for regression
####################################################################

"""
    calculateMSE(Σ, y, X, k)
Fits a linear model y=Xβ and returns the mean squared error (mse) from the model fit.

Here we take advantage of a precomputed covariance matrix Σ to solve for mse directly. There is a direct relation between mse and the covariance matrix: 

    mse = Σ(y,y) - Σ(X,y)ᵀΣ(X,X)⁻¹Σ(X,y)
    
`k` determines the number of free parameters (i.e. number of columns in X) in the model.
"""
@inline function calculateMSE(Σ, y, X, k)

    #The regression is a horizontal line at mean so...
    #mse = (1/n)(y-ȳ)² = var(y) = Cov(y,y) 
    if k == 0
        return Σ[y, y]
    end

    #mse = Cov(y,y) - Cov(X,y)ᵀCov(X,X)⁻¹Cov(X,y) (see the end of this file)
    #If length(X)==1 then all Cov(⋅,⋅) calls are just numbers
    #mse = Cov(y,y) - Cov(X,y)²/Cov(X,X)
    if k == 1
        x₁ = first(X)
        return Σ[y, y] - Σ[x₁, y]^2 / Σ[x₁, x₁]
    end

    #Uses stack allocated arrays to quickly solve linear system
    #Beyond size 10, StaticArrays lose their advantage
    k == 2  && return staticSolve(Σ, X, y, Val(2))
    k == 3  && return staticSolve(Σ, X, y, Val(3))
    k == 4  && return staticSolve(Σ, X, y, Val(4))
    k == 5  && return staticSolve(Σ, X, y, Val(5))
    k == 6  && return staticSolve(Σ, X, y, Val(6))
    k == 7  && return staticSolve(Σ, X, y, Val(7))
    k == 8  && return staticSolve(Σ, X, y, Val(8))
    k == 9  && return staticSolve(Σ, X, y, Val(9))
    k == 10 && return staticSolve(Σ, X, y, Val(10))

    #Just give up and do a matrix solve. 
    #TODO worry about BLAS threads oversubscribing with parallelization
    return defaultSolve(Σ, X, y)
end


function staticSolve(Σ, X, y, ::Val{N}) where N
    #Convert SmallBitSets and SmallSet to vector for indexing 
    v = FixedVector{N,Int}(X) 
    Σxx = SMatrix{N, N}(Σ[v[i], v[j]] for i in 1:N, j in 1:N)
    Σxy = SVector{N}(Σ[v[i], y] for i in 1:N)
    
    F = cholesky(Symmetric(Σxx))
    return Σ[y, y] - dot(Σxy, F \ Σxy)
end

function defaultSolve(Σ, X, y)
    #Convert set to vector with no allocations
    #TODO Maybe pass capacity down to here?
    # Xᵥ = SmallVector{SmallCollections.capacity(X)}(X)  #only works for SmallSets
    Xᵥ = collect(X)
    @views begin
        F = cholesky(Symmetric(Σ[Xᵥ, Xᵥ]))
        Σxy = Σ[Xᵥ, y]
        return Σ[y, y] - dot(Σxy, F \ Σxy)
    end
end

####################################################################
# Scoring function
####################################################################

"""
    score(state::CurrentState, node, nodeSet)

Calculates a score using the mean-squared error found by regressing `node` onto the `nodeSet`. 

More Info: we want to calculate the log likelihood that `nodeSet` are the parents of our node

    score = log(P(data|Model)) ≈ -BIC/2

because we're only comparing log likelihoods we'll ignore the 1/2 factor. When P(⋅) is Guassian, log(P(data|Model)) takes the form:
    score = -k⋅log(n) - n⋅log(mse)
k is the number of free parameters, n is the number of observations, and mse is mean squared error
"""
function _score(stats::SufficientStats, node, nodeSet)

    #Number of observations
    n = stats.observationsCount

    #Number of free parameters
    k = length(nodeSet)

    #Calculate the mean squared error (using covariance matrix approach)
    mse = calculateMSE(stats.covariance, node, nodeSet, k)

    #Penalty value for BIC
    p = stats.penalty

    #Return the score
    return -p * k * log(n) - n * log(mse)
end


####################################################################
# Scoring function Cache
####################################################################

struct CachedScore{S,C}
    stats::S
    cache::C
end


function CachedScore(stats::S, ::Type{M}; maxsize=100_000) where {S,M}
    cache = LRUCache{Tuple{Int,M},Float64}(maxsize)
    CachedScore(stats, cache)
end

function (cs::CachedScore)(node::Int, nodeSet::AbstractSet)

    #TODO find the cutoff for when dict lookup is faster than matrix solve
    if length(nodeSet) ≤ 10
        return _score(cs.stats, node, nodeSet)
    end

    key = (node, nodeSet)

    get!(cs.cache, key) do
        _score(cs.stats, node, nodeSet)
    end
end

#Updates the operator's score
function (score::CachedScore)(op::InsertOperator)

    (; x, y, T, parentsY, NAyx) = op #gettin' fancy with the struct unpacking

    NAyxTPaY = NAyx ∪ T ∪ parentsY

    scoreDelta = score(y, push(NAyxTPaY, x)) - score(y, NAyxTPaY)

    return setScore(op, scoreDelta)
end


function (score::CachedScore)(op::DeleteOperator)

    (; x, y, H, parentsY, NAyx) = op

    NAyxHPaY = setdiff(NAyx, H) ∪ parentsY

    scoreDelta = score(y, delete(NAyxHPaY, x)) - score(y, NAyxHPaY)

    return setScore(op, scoreDelta)
end


function (score::CachedScore)(op::TurnOperator)

    (; x, y, T, NAyx, parentsY, parentsX) = op

    NAyxTPaY = NAyx ∪ T ∪ parentsY

    scoreDelta = score(y, push(NAyxTPaY, x)) - score(y, NAyxTPaY) + 
                 score(x, delete(parentsX, y)) - score(x, parentsX)

    return setScore(op, scoreDelta)
end


#=
This is a derivation connecting mean squared error to the covariance matrix.

One definition of mean squared error 
    mse = (1/n) eᵀe    where e = y-ŷ (the residual)

Substitute the estimate ŷ = Xβ
    mse = (1/n)*(y - Xβ)ᵀ(y - Xβ)  

Plug in β = (XᵀX)⁻¹Xᵀy (the ordinary least squares solution)
    mse = (1/n)*(y - X(XᵀX)⁻¹Xᵀy)ᵀ(y - X(XᵀX)⁻¹Xᵀy)

Let H = X(XᵀX)⁻¹Xᵀ (the projection or "hat" matrix)
Note two properties of H: it is symmetric (Hᵀ = H) and idempotent (HH = H)
Substitute H into the expanded mean square error equation
    mse = (1/n)*(y - Hy)ᵀ(y - Hy)

Distribute the transpose across the first term (since H is symmetric, (Hy)ᵀ = yᵀH)
    mse = (1/n)*(yᵀ - yᵀH)(y - Hy)

Multiply the terms together (FOIL)
    mse = (1/n)*(yᵀy - yᵀHy - yᵀHy + yᵀHHy)

Since H is idempotent (HH = H), the last term simplifies
    mse = (1/n)*(yᵀy - 2yᵀHy + yᵀHy)
    mse = (1/n)*(yᵀy - yᵀHy)

Substitute H back into the equation
    mse = (1/n)*(yᵀy - yᵀX(XᵀX)⁻¹Xᵀy)

Distribute the (1/n)
    mse = (1/n)yᵀy - (1/n)yᵀX(XᵀX)⁻¹Xᵀy

Assuming X and y are mean-centered, define the sample covariance matrices:
    Cov(y,y) = (1/n)yᵀy
    Cov(X,X) = (1/n)XᵀX   =>  XᵀX = n*Cov(X,X)
    Cov(X,y) = (1/n)Xᵀy   =>  Xᵀy = n*Cov(X,y)
    yᵀX = (Xᵀy)ᵀ          =>  yᵀX = n*Cov(X,y)ᵀ

Substitute these covariance equivalents into the MSE equation
    mse = Cov(y,y) - (1/n) * [n*Cov(X,y)ᵀ] * [n*Cov(X,X)]⁻¹ * [n*Cov(X,y)]

Cancel out the 'n' by distributing the 1/n term 
    mse = Cov(y,y) - Cov(X,y)ᵀCov(X,X)⁻¹Cov(X,y)
=#