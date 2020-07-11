struct Scenario{R,G1,G2,G3,T,P,I<:AbstractProblem{R,G1,G2,G3,T,P}}

    probability::Float64
    parentscenario::Union{Scenario{R,G1,G2,G3,T,P},Nothing}
    childscenarios::Vector{Scenario{R,G1,G2,G3,T,P}}
    investmentproblem::I

    investments::Investments{R,G1,G2,G3}
    operations::Operations{R,G1,G2,G3,T,P}
    markets::Markets{R,T,P}

    periodweights::Vector{Float64}

    function Scenario{}(
        probability::Float64,
        parentscenario::Scenario{R,G1,G2,G3,T,P,I},
        childscenarios::Vector{Scenario{R,G1,G2,G3,T,P,I}},
        investmentproblem::I,
        investments::Investments{R,G1,G2,G3},
        operations::Operations{R,G1,G2,G3,T,P},
        markets::Markets{R,T,P},
        periodweights::Vector{Float64}
) where {R,G1,G2,G3,T,P,I<:AbstractProblem{R,G1,G2,G3,T,P}}

        @assert length(periodweights) == P
        @assert 0 < probability <= 1

        new{R,G1,G2,G3,T,P,I}(
            probability, parentscenario, childscenarios, investmentproblem,
            investments, operations, markets, periodweights)

    end

end

function Scenario(
    parent::Scenario, p::Float64,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,T,P},
    markets::Markets{R,T,P},
    weights::Vector{Float64}
) where {R,G1,G2,G3,T,P}

    s = Scenario(
        p, parent, Scenario{R,G1,G2,G3,T,P}[], parent.investmentproblem,
        investments, operations, markets, weights)

    return setup!(s)

end

function Scenario(
    invprob::I,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,T,P},
    markets::Markets{R,T,P},
    weights::Vector{Float64}
) where {R,G1,G2,G3,T,P,I<:AbstractProblem{R,G1,G2,G3,T,P}}

    s = Scenario(1.0, nothing, Scenario{R,G1,G2,G3,T,P}[], invprob,
                 investments, operations, markets, weights)

    return setup!(s)

end

function setup!(s::Scenario)

    ip = s.investmentproblem
    m = ip.model

    invs = s.investments
    ops = s.operations
    markets = s.markets
    weights = s.periodweights

    # Investments
    if isnothing(s.parent)
        setup!(invs.thermalgens,  m, ip.thermalstart)
        setup!(invs.variablegens, m, ip.variablestart)
        setup!(invs.storages,     m, ip.storagestart)
    else
        parentinvs = s.parent.investments
        setup!(invs.thermalgens,  ip.thermaltechs,  m, parentinvs.thermalgens)
        setup!(invs.variablegens, ip.variabletechs, m, parentinvs.variablegens)
        setup!(invs.storages,     ip.storagetechs,  m, parentinvs.storages)
    end

    # Operations
    setup!(ops.thermalgens,  ip.thermaltechs,  m, invs.thermalgens, weights)
    setup!(ops.variablegens, ip.variabletechs, m, invs.variablegens, weights)
    setup!(ops.storages,     ip.storagetechs,  m, invs.storages, weights)

    # Markets
    setup!(markets.capacity,     m, ops, weights)
    setup!(markets.energy,       m, ops, weights)
    setup!(markets.raisereserve, m, ops, weights)
    setup!(markets.lowerreserve, m, ops, weights)

    return s

end

function maturing(
    s::Scenario, r::Int, g::Int,
    leadtime::Symbol, action::Symbol)

    stepsback = 0
    count = zero(getfield(s.invs, action))[r,g]
    historical = s

    while !isnothing(historical)

        if getfield(historical.invs, leadtime)[r,g] == stepsback
            count += getfield(historical.invs, action)[r,g]
        end

        historical = s.parent
        stepsback += 1

    end

    return count

end

welfare(s::Scenario) =
    welfare(s.investments) + welfare(s.operations) + welfare(s.markets) +
    s.investmentproblem.discountrate *
    sum(cs.probability * welfare(cs) for cs in s.childscenarios)
