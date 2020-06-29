struct Markets{R,T,P}
   capacity::CapacityMarket
   energy::EnergyMarket{R,T,P}
   raisereserve::RaiseReserveMarket{R,T,P}
   lowerreserve::LowerReserveMarket{R,T,P}
end

welfare(x::Markets) =
    welfare(x.capacity) + welfare(x.energy) +
    welfare(x.raisereserve) + welfare(x.lowerreserve)

function setupmarkets!(s::Scenario)
    # Wire up variables, expresssions, and constraints
end

struct CapacityMarket # Assumes a linear demand curve

    # Parameters

    targetprice::Float64    # $/MW/investment period
    targetcapacity::Float64 # MW
    demandslope::Float64    # $/MW^2/investment period

    # Expressions

    capacitywelfare::ExpressionRef # Capacity market welfare

    function CapacityMarket(targetprice, targetcapacity, demandslope)
        @assert targetprice  >= 0
        @assert targetcapacity >= 0
        @assert demandslope <= 0
        new(targetprice, targetcapacity, demandslope)
    end


end

welfare(x::CapacityMarket) = x.capacitywelfare


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

welfare(x::EnergyMarket) = -x.shortfallcost


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
        R, T = size(demand)
        new{R,T}(demand, pricecap)
    end

end

welfare(x::RaiseReserveMarket) = -sum(x.shortfallcost)


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

welfare(x::LowerReserveMarket) = -sum(x.shortfallcost)
