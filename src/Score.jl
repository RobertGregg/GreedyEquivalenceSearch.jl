####################################################################
# Precomputed statisitics for scoring
####################################################################

"""
Pre-computed sufficient statistics for Gaussian BIC.
Stores the covariance matrix, sample size, and feature count.
"""
struct SufficientStats{T<:AbstractMatrix{<:AbstractFloat}}
    covariance::T
    observationsCount::Int
    variablesCount::Int
end


function SufficientStats(data)
    covariance = cov(data, corrected=false)
    observationsCount, variablesCount = size(data)

    return SufficientStats(covariance, observationsCount, variablesCount)
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
    Xᵥ = SmallVector{SmallCollections.capacity(X)}(X)
    #TODO Consider cholesky
    return @views Σ[y,y] - Σ[Xᵥ,y]' * (Σ[Xᵥ,Xᵥ] \ Σ[Xᵥ,y])
end


####################################################################
# Scoring function
####################################################################

#TODO Add penalty value for GES: -p⋅k⋅log(n) - n⋅log(mse)
"""
    score(state::CurrentState, node, nodeSet)

Calculates a score using the mean-squared error found by regressing `node` onto the `nodeSet`. 

More Info: we want to calculate the log likelihood that `nodeSet` are the parents of our node

    score = log(P(data|Model)) ≈ -BIC/2

because we're only comparing log likelihoods we'll ignore the 1/2 factor. When P(⋅) is Guassian, log(P(data|Model)) takes the form:
    score = -k⋅log(n) - n⋅log(mse)
k is the number of free parameters, n is the number of observations, and mse is mean squared error
"""
function score(stats::SufficientStats, node, nodeSet)
    
    #Number of observations
    n = stats.observationsCount

    #Number of free parameters
    k = length(nodeSet)
    
    #Calculate the mean squared error (using covariance matrix approach)
    mse = calculateMSE(stats.covariance, node, nodeSet, k)
    
    #Return the score
    return -k*log(n) - n*log(mse)
end