mutable struct LowerReserveMarket{R,T,P} # Assumes completely inelastic demand

    # Parameters
    demand::Array{Float64,3}  # (MW, r x t x p)
    pricecap::Vector{Float64} # ($/MW, r)

    # Variables
    shortfall::Array{VariableRef,3}  # Lower reserve shortfall (MW, r x t x p)

    # Expressions
    shortfallcost::Matrix{ExpressionRef} # Shortfall costs ($, p)
    totalshortfallcost::Vector{ExpressionRef} # Shortfall costs ($, p)

    # Constraints
    minshortfall::Array{GreaterThanConstraintRef,3} # Minimum reserve shortfall (r x t x p)
    marketclearing::Array{EqualToConstraintRef,3} # Reserve balance

    function LowerReserveMarket{}(demand, pricecap)

        R, T, P = size(demand)

        @assert all(x -> x >= 0, demand)
        @assert all(x -> x >= 0, pricecap)
        @assert length(pricecap) == R

        new{R,T,P}(demand, pricecap)

    end

end

function setup!(
    market::LowerReserveMarket{R,T,P}, m::Model,
    ops::Operations{R,G1,G2,G3,I,T,P}, periodweights::Vector{Float64}
) where {R,G1,G2,G3,I,T,P}

    # Variables

    market.shortfall =
        @variable(m, [r in 1:R, t in 1:T, p in 1:P])

    # Expressions

    market.shortfallcost =
        @expression(m, [r in 1:R, p in 1:P],
                    sum(market.shortfall[r,t,p] * market.pricecap[r]
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
                    lowerreserve(ops, r, t, p) + market.shortfall[r,t,p] ==
                    market.demand[r,t,p])

    return

end

welfare(x::LowerReserveMarket) = -sum(x.shortfallcost)
