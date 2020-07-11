struct RaiseReserveMarket{R,T,P} # Assumes completely inelastic demand

    # Parameters
    demand::Array{Float64,3} # (MW, r x t x p)
    pricecap::Float64       # $/MW

    # Variables
    shortfall::Array{VariableRef,3} # Raise reserve shortfall (MW, r x t x p)

    # Expressions
    shortfallcost::Vector{ExpressionRef} # Shortfall costs ($, p)

    # Constraints
    minshortfall::Array{<:ConstraintRef,3} # Minimum reserve shortfall (r x t x p)
    marketclearing::Array{<:ConstraintRef,3} # Reserve balance

    function RaiseReserveMarket{}(demand, pricecap)
        @assert all(x -> x >= 0, demand)
        @assert pricecap >= 0
        R, T, P = size(demand)
        new{R,T, P}(demand, pricecap)
    end

end

function setup!(
    market::RaiseReserveMarket{R,T,P}, m::Model, ops::Operations{R,G1,G2,G3,T,P}
) where {R,G1,G2,G3,T,P}

    regions = 1:R
    timesteps = 1:T
    periods = 1:P

    # Variables

    market.shortfall .=
        @variable(m, [r in regions, t in timesteps, p in periods])

    # Expressions

    market.shortfallcost .=
        @expression(m, [r in regions, p in periods],
                    sum(market.shortfall[r,t,p] * market.pricecap
                        for t in timesteps))

    market.totalshortfallcost .=
        @expression(m, [r in regions],
            sum(market.shortfallcost[r,p] * periodweights[p] for p in periods))

    # Constraints

    market.minshortfall .=
        @constraint(m, [r in regions, t in timesteps, p in periods],
                    market.shortfall[r,t,p] >= 0)

    market.marketclearning .=
        @constraint(m, [r in regions, t in timesteps, p in periods],
                    raisereserve(ops, r, t, p) + market.shortfall[r,t,p] ==
                    market.demand[r,t,p])

    return

end

welfare(x::RaiseReserveMarket) = -sum(x.shortfallcost)
