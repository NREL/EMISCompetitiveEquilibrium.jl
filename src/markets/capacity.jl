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

function setup!(market::CapacityMarket, m::Model, ops::Operations)
end

welfare(x::CapacityMarket) = x.capacitywelfare
