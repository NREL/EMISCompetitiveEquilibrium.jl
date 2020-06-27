struct CapacityMarket # Assumes a linear demand curve

    # Parameters

    targetprice::Float64    # $/MW/investment period
    targetcapacity::Float64 # MW
    demandslope::Float64    # $/MW^2/investment period

    # Expressions

    capacitywelfare::ExpressionRef # Capacity market welfare

    function CapacityMarket(p, q, m)
        @assert p >= 0
        @assert q >= 0
        @assert m <= 0
        new(p, q, m)
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
    # Power balance
    # Minimum shortfall

    function EnergyMarket{}(demand::Matrix{Float64}, pricecap::Float64)
        @assert all(demand .>= 0)
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
    # Reserve provision balance
    # Minimum shortfall

    function RaiseReserveMarket{}(demand::Matrix{Float64}, pricecap::Float64)
        @assert all(demand .>= 0)
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
    # Reserve provision balance
    # Minimum shortfall

    function LowerReserveMarket{}(demand::Matrix{Float64}, pricecap::Float64)
        @assert all(demand .>= 0)
        @assert pricecap >= 0
        R, T = size(demand)
        new{R,T}(demand, pricecap)
    end

end

welfare(x::LowerReserveMarket) = -sum(x.shortfallcost)
