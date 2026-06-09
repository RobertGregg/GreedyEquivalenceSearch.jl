####################################################################
# Precomputed statisitics for scoring
####################################################################

"""
Pre-computed sufficient statistics for Gaussian BIC.
Stores the covariance matrix, sample size, and feature count.
"""
struct SufficientStats{F<:AbstractFloat, T<:AbstractMatrix{F}}
    covariance::T
    observationsCount::Int
    variablesCount::Int
    penalty::F
end


function SufficientStats(data; penalty)

    #Computes the covariance matrix of the mean centered features
    #corrected=false divides by n instead of n-1
    #both needed to get correct regression results
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

Here we take advantage of a precomputed covariance matrix to solve for mse directly. `k` determines the number of free parameters (i.e. number of columns in X) in the model.
"""
function calculateMSE(Σ, y, X, k)
    
    #The regression is a horizontal line at mean so...
    #mse = (1/n)(y-ȳ)² = var(y) = Cov(y,y) 
    if k == 0
        return Σ[y,y]
    end

    #mse = Cov(y,y) - Cov(X,y)ᵀCov(X,X)⁻¹Cov(X,y) (see below)
    #If length(X)==1 then all Cov(⋅,⋅) calls are just numbers
    #mse = Cov(y,y) - Cov(X,y)²/Cov(X,X)
    if k == 1
        x₁ = first(X)
        return Σ[y,y] - Σ[x₁,y]^2 / Σ[x₁,x₁]
    end

    #Okay this is getting involved
    if k == 2
        x₁, x₂ = X

        v₁ = Σ[x₁, x₁]
        v₂ = Σ[x₂, x₂]
        c₁ = Σ[x₁, y]
        c₂ = Σ[x₂, y]
        c  = Σ[x₁, x₂]

        return Σ[y,y] - (v₁*c₂^2 + v₂*c₁^2 - 2*c₁*c₂*c)/(v₁*v₂ - c^2)
    end

    #Just give up and do a matrix solve 
    #mse = (1/n) eᵀe    where e = y-ŷ (the residual)
    #mse = (1/n)*(y - Xβ)ᵀ(y - Xβ)  plug in β = (XᵀX)⁻¹Xᵀy (OLS solution)
    #mse = (1/n)*(y - X(XᵀX)⁻¹Xᵀy)ᵀ(y - X(XᵀX)⁻¹Xᵀy)
    #lots of algebra...
    #mse = (1/n)*(yᵀy - yᵀX(XᵀX)⁻¹Xᵀy)
    #mse = Cov(y,y) - Cov(X,y)ᵀCov(X,X)⁻¹Cov(X,y)

    #Convert set to vector with no allocations
    # Xᵥ = SmallVector{SmallCollections.capacity(X)}(X)
    Xᵥ = collect(X) #TODO NEED TO MAKE THIS DYNAMIC

    
    return @views Σ[y,y] - Σ[Xᵥ,y]' * (cholesky(Σ[Xᵥ,Xᵥ]) \ Σ[Xᵥ,y])
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
    return -p*k*log(n) - n*log(mse)
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

    if length(nodeSet) ≤ 2
        return _score(cs.stats, node, nodeSet)
    end

    key = (node, nodeSet)

    get!(cs.cache, key) do
        _score(cs.stats, node, nodeSet)
    end
end

#Updates the operator's score
function (score::CachedScore)(op::InsertOperator)
   
    (; x, y, T, parentsY) = op #gettin' fancy with the struct unpacking

    TPaY = T ∪ parentsY

    scoreDelta = score(y, push(TPaY, x)) - score(y, TPaY)

    return setScore(op, scoreDelta)
end


function (score::CachedScore)(op::DeleteOperator)
   
    (; x, y, H, parentsY) = op

    scoreDelta = score(y, setdiff(H ∪ parentsY, x)) - score(y, H ∪ parentsY)

    return setScore(op, scoreDelta)
end