struct Scenario{R,G1,G2,G3,I,T,P,IP<:AbstractProblem{R,G1,G2,G3,I,T,P}
} <: AbstractScenario

    name::String
    probability::Float64
    parent::Union{Scenario{R,G1,G2,G3,I,T,P,IP},Nothing}
    children::Vector{Scenario{R,G1,G2,G3,I,T,P,IP}}
    investmentproblem::IP

    investments::Investments{R,G1,G2,G3}
    operations::Operations{R,G1,G2,G3,I,T,P}
    markets::Markets{R,T,P}

    periodweights::Vector{Float64}

    function Scenario{}(
        name::String,
        probability::Float64,
        parentscenario::Union{Scenario{R,G1,G2,G3,I,T,P,IP},Nothing},
        childscenarios::Vector{Scenario{R,G1,G2,G3,I,T,P,IP}},
        investmentproblem::IP,
        investments::Investments{R,G1,G2,G3},
        operations::Operations{R,G1,G2,G3,I,T,P},
        markets::Markets{R,T,P},
        periodweights::Vector{Float64}
) where {R,G1,G2,G3,I,T,P,IP<:AbstractProblem{R,G1,G2,G3,I,T,P}}

        @assert length(periodweights) == P
        @assert 0 < probability <= 1

        s = new{R,G1,G2,G3,I,T,P,IP}(
            name, probability, parentscenario, childscenarios,
            investmentproblem, investments, operations, markets, periodweights)

        isnothing(parentscenario) || push!(parentscenario.children, s)

        return s

    end

end

function Scenario(
    parent::Scenario{R,G1,G2,G3,I,T,P,IP},
    name::String, p::Float64,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,I,T,P},
    markets::Markets{R,T,P},
    weights::Vector{Float64}
) where {R,G1,G2,G3,I,T,P,IP}

    s = Scenario(
        name, p, parent, Scenario{R,G1,G2,G3,I,T,P,IP}[],
        parent.investmentproblem, investments, operations, markets, weights)

    return setup!(s)

end

function Scenario(
    invprob::IP,
    name::String,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,I,T,P},
    markets::Markets{R,T,P},
    weights::Vector{Float64}
) where {R,G1,G2,G3,I,T,P,IP<:AbstractProblem{R,G1,G2,G3,I,T,P}}

    s = Scenario(name, 1.0, nothing, Scenario{R,G1,G2,G3,I,T,P,IP}[], invprob,
                 investments, operations, markets, weights)

    return setup!(s)

end

function loadscenario(
    regions::Dict{String,Int}, techs::Technologies,
    periods::Dict{String,Int}, n_timesteps::Int,
    scenariofolder::String)

    resourcepath = joinpath(scenariofolder, "resources")
    investments = loadinvestments(techs, regions, resourcepath)
    operations = loadoperations(
        techs, regions, periods, n_timesteps, resourcepath)
    markets = loadmarkets(
        regions, periods, n_timesteps, joinpath(scenariofolder, "markets"))

    return investments, operations, markets

end

function setup!(s::Scenario)

    ip = s.investmentproblem
    m = ip.model

    invs = s.investments
    ops = s.operations
    markets = s.markets
    weights = s.periodweights

    # Investments
    setup!(s, :thermal, m, ip.initialconditions.thermal)
    setup!(s, :variable, m, ip.initialconditions.variable)
    setup!(s, :storage, m, ip.initialconditions.storage)

    # Operations
    setup!(ops.thermal,  ip.technologies.thermal,   m, invs.thermal, weights, s)
    setup!(ops.variable, ip.technologies.variable,  m, invs.variable, weights, s)
    setup!(ops.storage,     ip.technologies.storage,   m, invs.storage, weights, s)
    setup!(ops.transmission, ip.technologies.interface, m)

    # Markets
    setup!(markets.capacity,     m, ops, s)
    setup!(markets.rec,          m, ops, weights, s)
    setup!(markets.energy,       m, ops, weights, s)
    setup!(markets.raisereserve, m, ops, weights, s)
    setup!(markets.lowerreserve, m, ops, weights, s)

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
        if getfield(invs, leadtime)[r,g] == stepsback
            count += getfield(invs, action)[r,g]
        end

        historical = historical.parent
        stepsback += 1

    end

    return count

end

function welfare(s::Scenario)

    discountrate = s.investmentproblem.discountrate
    oneoffwelfare = welfare(s.investments)
    recurringwelfare = welfare(s.operations) + welfare(s.markets)

    return if length(s.children) > 0
        # Current + discounted future welfare
        oneoffwelfare + recurringwelfare + discountrate *
        sum(cs.probability * welfare(cs) for cs in s.children)
    else
        # Repeat recurring welfare forever
        oneoffwelfare + recurringwelfare / (1 - discountrate)
    end

end

function discount(s::Scenario)

    haschildren = length(s.children) > 0
    discountrate = s.investmentproblem.discountrate

    discountings = 0
    while s.parent != nothing
        discountings += 1
        s = s.parent
    end

    oneoffrate = discountrate ^ discountings
    recurringrate = haschildren ? oneoffrate : oneoffrate / (1 - discountrate)

    return oneoffrate, recurringrate

end
