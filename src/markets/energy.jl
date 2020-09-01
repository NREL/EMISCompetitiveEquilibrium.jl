mutable struct EnergyMarket{R,T,P} # Assumes completely inelastic demand

    # Parameters
    demand::Array{Float64,3} # (MW, r x t x p)
    pricecap::Float64        # $/MW

    # Variables
    shortfall::Array{VariableRef,3} # Load shortfall variable (MW, r x t x p)

    # Expressions
    shortfallcost::Matrix{ExpressionRef} # Shortfall costs ($, r x p)
    totalshortfallcost::Vector{ExpressionRef} # Shortfall costs ($, r x p)

    # Constraints
    minshortfall::Array{GreaterThanConstraintRef,3} # Minimum load shortfall (r x t x p)
    marketclearing::Array{EqualToConstraintRef,3} # Power balance (r x t x p)

    function EnergyMarket{}(demand::Array{Float64,3}, pricecap::Float64)
        @assert all(x -> x >= 0, demand)
        @assert pricecap >= 0
        R, T, P = size(demand)
        new{R,T,P}(demand, pricecap)
    end

end

function setup!(
    market::EnergyMarket{R,T,P}, m::Model,
    ops::Operations{R,G1,G2,G3,I,T,P}, periodweights::Vector{Float64}
) where {R,G1,G2,G3,I,T,P}

    # Variables

    market.shortfall =
        @variable(m, [r in 1:R, t in 1:T, p in 1:P])

    # Expressions

    market.shortfallcost =
        @expression(m, [r in 1:R, p in 1:P],
                    sum(market.shortfall[r,t,p] * market.pricecap
                        for t in 1:T))

    market.totalshortfallcost =
        @expression(m, [r in 1:R],
            sum(market.shortfallcost[r,p] * periodweights[p] for p in 1:P))

    # Constraints

    market.minshortfall =
        @constraint(m, [r in 1:R, t in 1:T, p in 1:P],
                    market.shortfall[r,t,p] >= 0)

    market.marketclearing =
        @constraint(m, [r in 1:R, t in 1:T, p in 1:P],
                    energy(ops, r, t, p) + market.shortfall[r,t,p] ==
                    market.demand[r,t,p] + ops.transmission.exports[r,t,p])

    return

end

welfare(x::EnergyMarket) = -sum(x.shortfallcost)
