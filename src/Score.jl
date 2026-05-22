"""
    calculateMSE(Σ, X, y, k)
Fits a linear model y=Xβ and returns the mean squared error (mse) from the model fit.

Here we take advantage of a precomputed covariance matrix to solve for mse directly. `k` determines the number of free parameters (i.e. number of columns in X) in the model.
"""
function calculateMSE(Σ, X, y, k)
    
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
        x₁ = first(X)
        x₂ = last(X)

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

    #TODO Consider cholesky
    return @views Σ[y,y] - Σ[X,y]' * (Σ[X,X] \ Σ[X,y])
end