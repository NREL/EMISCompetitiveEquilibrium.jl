struct EnergyMarket{R,T,P} # Assumes completely inelastic demand

    # Parameters
    demand::Array{Float64,3} # (MW, r x t x p)
    pricecap::Float64        # $/MW

    # Variables
    shortfall::Array{VariableRef,3} # Load shortfall variable (MW, r x t x p)

    # Expressions
    shortfallcost::Vector{ExpressionRef} # Shortfall costs ($, p)

    # Constraints
    minshortfall::Array{<:ConstraintRef,3} # Minimum load shortfall (r x t x p)
    marketclearning::Array{<:ConstraintRef,3} # Power balance (r x t x p)

    function EnergyMarket{}(demand::Matrix{Float64}, pricecap::Float64)
        @assert all(x -> x >= 0, demand)
        @assert pricecap >= 0
        R, T = size(demand)
        new{R,T}(demand, pricecap)
    end

end

function setup!(
    market::EnergyMarket{R,T,P}, m::Model, ops::Operations{R,G1,G2,G3,T,P}
) where {R,G1,G2,G3,T,P}
end

welfare(x::EnergyMarket) = -x.shortfallcost
