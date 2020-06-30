struct Scenario{R,G1,G2,G3,T,P}

    probability::Float64
    parentscenario::Union{Scenario{R,G1,G2,G3,T,P},Nothing}
    childscenarios::Vector{Scenario{R,G1,G2,G3,T,P}}
    investmentproblem::InvestmentProblem{R,G1,G2,G3,T,P}

    investments::Investments{R,G1,G2,G3}
    operations::Operations{R,G1,G2,G3,T,P}
    markets::Markets{R,T,P}

end

function Scenario(
    parent::Scenario, p::Float64,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,T,P},
    markets::Markets{R,T,P}
) where {R,G1,G2,G3,T,P}

    s = Scenario(
        p, parent, Scenario{R,G1,G2,G3,T,P}[], parent.investmentproblem,
        investments, operations, markets)

    return setup!(s)

end

function Scenario(
    invprob::InvestmentProblem,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,T,P},
    markets::Markets{R,T,P}
) where {R,G1,G2,G3,T,P}

    s = Scenario(1.0, nothing, Scenario{R,G1,G2,G3,T,P}[], invprob,
                 investments, operations, markets)

    return setup!(s)

end

function setup!(s::Scenario)

    m = s.investmentproblem.model
    invs = s.investments
    ops = s.operations
    markets = s.markets

    # Investments
    if isnothing(s.parent)
        initconds = s.investmentproblem.initialconditions
        setup!(invs.thermalgens, m, initconds.thermal_existingunits)
        setup!(invs.variablegens, m, initconds.variable_existingunits)
        setup!(invs.storages, m, initconds.storage_existingunits)
    else
        parentinvs = s.parent.investments
        setup!(invs.thermalgens, m, parentinvs.thermalgens)
        setup!(invs.variablegens, m, parentinvs.variablegens)
        setup!(invs.storages, m, parentinvs.storages)
    end

    # Operations
    setup!(ops.thermalgens, m, invs.thermalgens)
    setup!(ops.variablegens, m, invs.variablegens)
    setup!(ops.storages, m, invs.storages)

    # Markets
    setup!(markets.capacity, m, ops)
    setup!(markets.energy, m, ops)
    setup!(markets.raisereserve, m, ops)
    setup!(markets.lowerreserve, m, ops)

    return s

end

welfare(s::Scenario) =
    welfare(s.investments) + welfare(s.operations) + welfare(s.markets) +
    s.investmentproblem.discountrate *
    sum(cs.probability * welfare(cs) for cs in s.childscenarios)
