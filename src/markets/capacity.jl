mutable struct CapacityMarket # Assumes a linear demand curve

    # Parameters

    targetprice::Float64    # $/MW/investment period
    targetcapacity::Float64 # MW
    demandslope::Float64    # $/MW^2/investment period

    # Expressions

    capacitywelfare::QuadExpressionRef # Capacity market welfare

    function CapacityMarket(targetprice, targetcapacity, demandslope)
        @assert targetprice  >= 0
        @assert targetcapacity >= 0
        @assert demandslope <= 0
        new(targetprice, targetcapacity, demandslope)
    end

end

function CapacityMarket(capacitypath::String)

    capacitydata = DataFrame!(CSV.File(joinpath(capacitypath, "rules.csv")))

    targetprice = first(capacitydata.targetprice)
    targetcapacity = first(capacitydata.targetcapacity)
    demandslope = first(capacitydata.demandslope)

    return CapacityMarket(targetprice, targetcapacity, demandslope)

end

function setup!(market::CapacityMarket, m::Model, ops::Operations)

    startprice =
        market.targetprice - market.demandslope * market.targetcapacity

    ucap_ = ucap(ops)

    market.capacitywelfare =
        @expression(m, startprice * ucap_ + 0.5 * market.demandslope * ucap_^2)

end

welfare(x::CapacityMarket) = x.capacitywelfare
