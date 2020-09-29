mutable struct RECMarket # Assumes completely inelastic demand

    # Parameters
    demand::Float64   # annual renewable energy (MWh)
    pricecap::Float64 # alternate compliance cost ($/MWh)

    # Variables
    shortfall::VariableRef # RPS shortfall variable (MWh)

    # Expressions
    shortfallcost::ExpressionRef # Compliance penalty costs ($)

    # Constraints
    minshortfall::GreaterThanConstraintRef # Minimum RE shortfall
    marketclearing::GreaterThanConstraintRef # REC requirement

    function RECMarket(demand::Float64, pricecap::Float64)

        @assert demand >= 0
        @assert pricecap >= 0

        new(demand, pricecap)

    end

end

function RECMarket(marketpath::String)

    rulesdata = DataFrame!(CSV.File(joinpath(marketpath, "rules.csv"),
                                    types=scenarios_market_param_types))

    demand = first(rulesdata.demand)
    pricecap = first(rulesdata.pricecap)

    return RECMarket(demand, pricecap)

end

function setup!(
    market::RECMarket, m::Model,
    ops::Operations{R,G1,G2,G3,I,T,P}, periodweights::Vector{Float64},
    s::AbstractScenario
) where {R,G1,G2,G3,I,T,P}

    # Variables

    market.shortfall = @variable(m)
    set_name(market.shortfall, "shortfall_rec_$(s.name)")

    # Expressions

    market.shortfallcost = @expression(m, market.shortfall * market.pricecap)

    # Constraints

    market.minshortfall = @constraint(m, market.shortfall >= 0)

    market.marketclearing = @constraint(m,
        sum(periodweights[p] * sum(ops.variable.recenergy[:,:,p])
            for p in 1:P) + market.shortfall >= market.demand)

    return

end

welfare(x::RECMarket) = -x.shortfallcost
