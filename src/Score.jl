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

Here we take advantage of a precomputed covariance matrix Σ to solve for mse directly. `k` determines the number of free parameters (i.e. number of columns in X) in the model.
"""
function calculateMSE(Σ, y, X, k)

    #The regression is a horizontal line at mean so...
    #mse = (1/n)(y-ȳ)² = var(y) = Cov(y,y) 
    if k == 0
        return Σ[y, y]
    end

    #mse = Cov(y,y) - Cov(X,y)ᵀCov(X,X)⁻¹Cov(X,y) (see below)
    #If length(X)==1 then all Cov(⋅,⋅) calls are just numbers
    #mse = Cov(y,y) - Cov(X,y)²/Cov(X,X)
    if k == 1
        x₁ = first(X)
        return Σ[y, y] - Σ[x₁, y]^2 / Σ[x₁, x₁]
    end

    #Compute xᵀΣ⁻¹x
    # x = [x₁, x₂]
    # Σ = [a b; b c]
    if k == 2
        xᵢ, xⱼ = X

        x₁ = Σ[xᵢ, y]
        x₂ = Σ[xⱼ, y]
        a = Σ[xᵢ, xᵢ]
        b = Σ[xᵢ, xⱼ]
        c = Σ[xⱼ, xⱼ]

        return Σ[y, y] - (c * x₁^2 + a * x₂^2 - 2 * b * x₁ * x₂) / (a * c - b^2)
    end

    #Compute xᵀΣ⁻¹x
    # x = [x₁, x₂, x₃]
    # Σ = [a b c; b d e; c e f]
    if k == 3
        xᵢ, xⱼ, xₖ = X

        x₁ = Σ[xᵢ, y]
        x₂ = Σ[xⱼ, y]
        x₃ = Σ[xₖ, y]
        a = Σ[xᵢ, xᵢ]
        b = Σ[xᵢ, xⱼ]
        c = Σ[xᵢ, xₖ]
        d = Σ[xⱼ, xⱼ]
        e = Σ[xⱼ, xₖ]
        f = Σ[xₖ, xₖ]

        Δ = a * d * f + 2b * c * e - a * e^2 - d * c^2 - f * b^2

        return Σ[y, y] - ((d * f - e^2) * x₁^2 + (a * f - c^2) * x₂^2 + (a * d - b^2) * x₃^2 + 2(c * e - b * f) * x₁ * x₂ + 2(b * e - c * d) * x₁ * x₃ + 2(b * c - a * e) * x₂ * x₃) / Δ
    end

    #This hand written method is 10x faster than the matrix solve which is crazy
    # Compute xᵀΣ⁻¹x
    # x = [x₁, x₂, x₃, x₄]
    # Σ = [a b c d;
    #      b e f g;
    #      c f h i;
    #      d g i j]
    if k == 4
        xᵢ, xⱼ, xₖ, xₗ = X

        x₁ = Σ[xᵢ, y]
        x₂ = Σ[xⱼ, y]
        x₃ = Σ[xₖ, y]
        x₄ = Σ[xₗ, y]

        a = Σ[xᵢ, xᵢ]
        b = Σ[xᵢ, xⱼ]
        c = Σ[xᵢ, xₖ]
        d = Σ[xᵢ, xₗ]
        e = Σ[xⱼ, xⱼ]
        f = Σ[xⱼ, xₖ]
        g = Σ[xⱼ, xₗ]
        h = Σ[xₖ, xₖ]
        i = Σ[xₖ, xₗ]
        j = Σ[xₗ, xₗ]

        Δ =
            a * e * h * j - a * e * i^2 - a * f^2 * j + 2a * f * g * i - a * g^2 * h -
            b^2 * h * j + b^2 * i^2 + 2b * c * f * j - 2b * c * g * i -
            2b * d * f * i + 2b * d * g * h -
            c^2 * e * j + 2c * d * e * i + c^2 * g^2 -
            2c * d * f * g - d^2 * e * h + d^2 * f^2

        C11 = e * h * j - e * i^2 - f^2 * j + 2f * g * i - g^2 * h
        C22 = a * h * j - a * i^2 - c^2 * j + 2c * d * i - d^2 * h
        C33 = a * e * j - a * g^2 - b^2 * j + 2b * d * g - d^2 * e
        C44 = a * e * h - a * f^2 - b^2 * h + 2b * c * f - c^2 * e

        #so many cofactors...
        C12 = -b * h * j + b * i^2 + c * f * j - c * g * i - d * f * i + d * g * h
        C13 = b * f * j - b * g * i - c * e * j + c * g^2 + d * e * i - d * f * g
        C14 = -b * f * i + b * g * h + c * e * i - c * f * g - d * e * h + d * f^2

        C23 = -a * f * j + a * g * i + b * c * j - b * d * i - c * d * g + d^2 * f
        C24 = a * f * i - a * g * h - b * c * i + b * d * h + c^2 * g - c * d * f
        C34 = -a * e * i + a * f * g + b^2 * i - b * c * g - b * d * f + c * d * e

        return Σ[y, y] - (
            C11 * x₁^2 + C22 * x₂^2 + C33 * x₃^2 + C44 * x₄^2 +
            2C12 * x₁ * x₂ + 2C13 * x₁ * x₃ + 2C14 * x₁ * x₄ +
            2C23 * x₂ * x₃ + 2C24 * x₂ * x₄ + 2C34 * x₃ * x₄
        ) / Δ
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
    #TODO NEED TO MAKE THIS DYNAMIC
    Xᵥ = collect(X)


    #TODO worry about BLAS threads oversubscribing with parallelization
    return @views Σ[y, y] - Σ[Xᵥ, y]' * (cholesky(Σ[Xᵥ, Xᵥ]) \ Σ[Xᵥ, y])
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

    #The hard-coded small matrix solves are faster than LRU lookup
    if length(nodeSet) ≤ 4
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