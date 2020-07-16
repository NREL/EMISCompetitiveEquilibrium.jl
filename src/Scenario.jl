struct Scenario{R,G1,G2,G3,T,P,I<:AbstractProblem{R,G1,G2,G3,T,P}} <: AbstractScenario

    probability::Float64
    parent::Union{Scenario{R,G1,G2,G3,T,P},Nothing}
    children::Vector{Scenario{R,G1,G2,G3,T,P}}
    investmentproblem::I

    investments::Investments{R,G1,G2,G3}
    operations::Operations{R,G1,G2,G3,T,P}
    markets::Markets{R,T,P}

    periodweights::Vector{Float64}

    function Scenario{}(
        probability::Float64,
        parentscenario::Union{Scenario{R,G1,G2,G3,T,P,I},Nothing},
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

    s = Scenario(1.0, nothing, Scenario{R,G1,G2,G3,T,P,I}[], invprob,
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
    setup!(s, :thermalgens, m, ip.initialconditions.thermalgens)
    setup!(s, :variablegens, m, ip.initialconditions.variablegens)
    setup!(s, :storages, m, ip.initialconditions.storages)

    # Operations
    setup!(ops.thermalgens,  ip.technologies.thermal,  m, invs.thermalgens, weights)
    setup!(ops.variablegens, ip.technologies.variable, m, invs.variablegens, weights)
    setup!(ops.storages,     ip.technologies.storage,  m, invs.storages, weights)
    setup!(ops.transmission, m)

    # Markets
    setup!(markets.capacity,     m, ops)
    setup!(markets.energy,       m, ops, weights)
    setup!(markets.raisereserve, m, ops, weights)
    setup!(markets.lowerreserve, m, ops, weights)

    return s

end

function maturing(
    s::Scenario, r::Int, g::Int,
    invtype::Symbol, leadtime::Symbol, action::Symbol)

    stepsback = 0
    count = ExpressionRef()
    historical = s

    while !isnothing(historical)

        invs = getfield(historical.investments, invtype)
        if getfield(invs, leadtime)[g] == stepsback
            count += getfield(invs, action)[r,g]
        end

        historical = s.parent
        stepsback += 1

    end

    return count

end

welfare(s::Scenario) =
    welfare(s.investments) + welfare(s.operations) + welfare(s.markets) +
    s.investmentproblem.discountrate *
    ((length(s.children) > 0) ?
        sum(cs.probability * welfare(cs) for cs in s.children) : 0)
