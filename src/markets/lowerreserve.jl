struct LowerReserveMarket{R,T,P} # Assumes completely inelastic demand

    # Parameters
    demand::Array{Float64,3} # (MW, r x t x p)
    pricecap::Float64        # $/MW

    # Variables
    shortfall::Array{VariableRef,3}  # Lower reserve shortfall (MW, r x t x p)

    # Expressions
    shortfallcost::Vector{ExpressionRef} # Shortfall costs ($, p)

    # Constraints
    minshortfall::Array{<:ConstraintRef,3} # Minimum reserve shortfall (r x t x p)
    marketclearing::Array{<:ConstraintRef,3} # Reserve balance

    function LowerReserveMarket{}(demand, pricecap)
        @assert all(x -> x >= 0, demand)
        @assert pricecap >= 0
        R, T = size(demand)
        new{R,T}(demand, pricecap)
    end

end

function setup!(
    market::LowerReserveMarket{R,T,P}, m::Model, ops::Operations{R,G1,G2,G3,T,P}
) where {R,G1,G2,G3,T,P}
end

welfare(x::LowerReserveMarket) = -sum(x.shortfallcost)
