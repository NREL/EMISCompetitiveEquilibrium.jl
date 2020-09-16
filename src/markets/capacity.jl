mutable struct CapacityMarket # Assumes a linear demand curve

    # Parameters

    maxprice::Float64 # $/MW/investment period
    midprice::Float64

    maxprice_capacity::Float64 # MW
    midprice_capacity::Float64
    zeroprice_capacity::Float64

    # Variables

    seg0contribution::VariableRef
    seg1contribution::VariableRef
    seg2contribution::VariableRef

    # Expressions

    totalcontribution::ExpressionRef # Capacity clearing level
    seg1price::ExpressionRef
    seg2price::ExpressionRef
    capacitywelfare::QuadExpressionRef # Capacity market welfare

    # Constraints

    min_seg0contribution::GreaterThanConstraintRef
    max_seg0contribution::LessThanConstraintRef

    min_seg1contribution::GreaterThanConstraintRef
    max_seg1contribution::LessThanConstraintRef

    min_seg2contribution::GreaterThanConstraintRef
    max_seg2contribution::LessThanConstraintRef

    max_totalcontribution::LessThanConstraintRef

    function CapacityMarket(
        maxprice::Float64, midprice::Float64,
        maxprice_capacity::Float64, midprice_capacity::Float64,
        zeroprice_capacity::Float64
    )
        @assert maxprice >= midprice >= 0
        @assert 0 <= maxprice_capacity <= midprice_capacity <= zeroprice_capacity
        new(maxprice, midprice,
            maxprice_capacity, midprice_capacity, zeroprice_capacity)
    end

end

function CapacityMarket(capacitypath::String)

    capacitydata = DataFrame!(CSV.File(joinpath(capacitypath, "rules.csv"),
                                       types=scenarios_capacitymarket_param_types))

    maxprice = first(capacitydata.maxprice)
    midprice = first(capacitydata.midprice)
    maxprice_capacity = first(capacitydata.maxprice_capacity)
    midprice_capacity = first(capacitydata.midprice_capacity)
    zeroprice_capacity = first(capacitydata.zeroprice_capacity)

    return CapacityMarket(
        maxprice, midprice,
        maxprice_capacity, midprice_capacity, zeroprice_capacity)

end

function setup!(market::CapacityMarket, m::Model, ops::Operations, s::AbstractScenario)

    # Variables

    market.seg0contribution = @variable(m)
    set_name(market.seg0contribution, "seg0contribution_capacity_$(s.name)")

    market.seg1contribution = @variable(m)
    set_name(market.seg1contribution, "seg1contribution_capacity_$(s.name)")

    market.seg2contribution = @variable(m)
    set_name(market.seg2contribution, "seg2contribution_capacity_$(s.name)")

    # Expressions

    market.totalcontribution = @expression(m,
        market.seg0contribution + market.seg1contribution + market.seg2contribution)

    market.seg1price = @expression(m,
         market.maxprice - (market.maxprice - market.midprice) /
                           (market.midprice_capacity - market.maxprice_capacity) *
                           market.seg1contribution)

    market.seg2price = @expression(m,
         market.midprice - market.midprice /
                           (market.zeroprice_capacity - market.midprice_capacity) *
                           market.seg2contribution)

    market.capacitywelfare = @expression(m,
        market.seg0contribution * market.maxprice +
        market.seg1contribution * (market.maxprice + market.seg1price) / 2 +
        market.seg2contribution * (market.midprice + market.seg2price) / 2)

    # Constraints

    market.min_seg0contribution = @constraint(m,
        market.seg0contribution >= 0)

    market.max_seg0contribution = @constraint(m,
        market.seg0contribution <= market.maxprice_capacity)

    market.min_seg1contribution = @constraint(m,
        market.seg1contribution >= 0)

    market.max_seg1contribution = @constraint(m,
        market.seg1contribution <= market.midprice_capacity - market.maxprice_capacity)

    market.min_seg2contribution = @constraint(m,
        market.seg2contribution >= 0)

    market.max_seg2contribution = @constraint(m,
        market.seg2contribution <= market.zeroprice_capacity - market.midprice_capacity)

    market.max_totalcontribution = @constraint(m,
        market.totalcontribution <= ucap(ops))

end

welfare(x::CapacityMarket) = x.capacitywelfare
