mutable struct ThermalGeneratorOperations{R,G,T,P}

    # Parameters

    fixedcost::Matrix{Float64}    # $/unit/investment period, g
    variablecost::Matrix{Float64} # $/MW/hour, r x g
    startupcost::Matrix{Float64}  # $/startup/unit, r x g
    shutdowncost::Matrix{Float64} # $/shutdown/unit, r x g

    # Variables

    committed::Array{VariableRef,4} # Units committed (r x g x t x p)
    started::Array{VariableRef,4}   # Units started up
    shutdown::Array{VariableRef,4}  # Units shut down

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    fixedcosts::Matrix{ExpressionRef} # ($, r x g)
    variablecosts::Array{ExpressionRef,3} # ($, r x g x p)
    operatingcosts::Matrix{ExpressionRef} # ($, r x g)

    ucap::Vector{ExpressionRef} # (MW, r)
    totalenergy::Array{ExpressionRef,3} # MW, r x t x p
    totalraisereserve::Array{ExpressionRef,3}
    totallowerreserve::Array{ExpressionRef,3}

    # Constraints

    minunitcommitment::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxunitcommitment::Array{LessThanConstraintRef,4}
    minunitstartups::Array{GreaterThanConstraintRef,4}
    maxunitstartups::Array{LessThanConstraintRef,4}   # (r x g x t x p)
    minunitshutdowns::Array{GreaterThanConstraintRef,4}  # (r x g x t x p)
    maxunitshutdowns::Array{LessThanConstraintRef,4}  # (r x g x t x p)

    unitcommitmentcontinuity::Array{EqualToConstraintRef,4}  # (r x g x t x p)
    minunituptime::Array{LessThanConstraintRef,4} # (r x g x t x p)
    minunitdowntime::Array{LessThanConstraintRef,4}

    mingeneration::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{LessThanConstraintRef,4}
    minlowerreserve::Array{GreaterThanConstraintRef,4}
    maxlowerreserve::Array{LessThanConstraintRef,4}
    minraisereserve::Array{GreaterThanConstraintRef,4}
    maxraisereserve::Array{LessThanConstraintRef,4}

    maxrampdown::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxrampup::Array{LessThanConstraintRef,4}

    function ThermalGeneratorOperations{T,P}(
        fixedcost::Matrix{Float64},
        variablecost::Matrix{Float64},
        startupcost::Matrix{Float64},
        shutdowncost::Matrix{Float64}
    ) where {T,P}

        R, G = size(fixedcost)
        @assert size(variablecost) == (R, G)
        @assert size(startupcost) == (R, G)
        @assert size(shutdowncost) == (R, G)

        new{R,G,T,P}(fixedcost, variablecost, startupcost, shutdowncost)

    end

end

function ThermalGeneratorOperations{T,P}(
    thermalgens::ThermalGenerators{G}, regionlookup::Dict{String,Int},
    thermalpath::String
) where {G,T,P}

    R = length(regionlookup)
    thermaldata = DataFrame!(CSV.File(joinpath(thermalpath, "parameters.csv"),
                                      types=scenarios_resource_param_types))

    thermallookup = Dict(zip(thermalgens.name, 1:G))
    fixedcost = zeros(Float64, R, G)
    variablecost = zeros(Float64, R, G)
    startupcost = zeros(Float64, R, G)
    shutdowncost = zeros(Float64, R, G)

    for row in eachrow(thermaldata)

        gen_idx = thermallookup[row.class]
        region_idx = regionlookup[row.region]

        fixedcost[region_idx, gen_idx] = row.fixedcost
        variablecost[region_idx, gen_idx] = row.variablecost
        startupcost[region_idx, gen_idx] = row.startupcost
        shutdowncost[region_idx, gen_idx] = row.shutdowncost

    end

    return ThermalGeneratorOperations{T,P}(
        fixedcost, variablecost, startupcost, shutdowncost)

end

function setup!(
    ops::ThermalGeneratorOperations{R,G,T,P},
    units::ThermalGenerators{G},
    m::Model, invs::ResourceInvestments{R,G},
    periodweights::Vector{Float64},
    s::AbstractScenario
) where {R,G,T,P}

    invprob = s.investmentproblem
    Rs = invprob.regionnames
    Gs = units.name
    Ts = string.(1:T)
    Ps = invprob.periodnames

    # Variables

    ops.committed = @variable(m, [1:R, 1:G, 1:T, 1:P], Int)
    varnames!(ops.committed, "committed_thermal_$(s.name)", Rs, Gs, Ts, Ps)

    ops.started   = @variable(m, [1:R, 1:G, 1:T, 1:P], Int)
    varnames!(ops.started, "started_thermal_$(s.name)", Rs, Gs, Ts, Ps)

    ops.shutdown  = @variable(m, [1:R, 1:G, 1:T, 1:P], Int)
    varnames!(ops.shutdown, "shutdown_thermal_$(s.name)", Rs, Gs, Ts, Ps)

    ops.energydispatch = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.energydispatch, "energydispatch_thermal_$(s.name)", Rs, Gs, Ts, Ps)

    ops.raisereserve   = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.raisereserve, "raisereserve_thermal_$(s.name)", Rs, Gs, Ts, Ps)

    ops.lowerreserve   = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.lowerreserve, "lowerreserve_thermal_$(s.name)", Rs, Gs, Ts, Ps)

    # Expressions

    ops.fixedcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcost[r,g] * invs.dispatching[r,g])

    ops.variablecosts =
        @expression(m, [r in 1:R, g in 1:G, p in 1:P],
                    sum(ops.variablecost[r,g] * ops.energydispatch[r,g,t,p] +
                        ops.startupcost[r,g] * ops.started[r,g,t,p] +
                        ops.shutdowncost[r,g] * ops.shutdown[r,g,t,p]
                        for t in 1:T))

    ops.operatingcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p] for p in 1:P))

    ops.ucap =
        @expression(m, [r in 1:R], G > 0 ? sum(
            invs.dispatching[r,g] * units.maxgen[g] * units.capacitycredit[g]
        for g in 1:G) : 0)

    ops.totalenergy =
        @expression(m, [r in 1:R, t in 1:T, p in 1:P],
                    G > 0 ? sum(ops.energydispatch[r,g,t,p] for g in 1:G) : 0)

    ops.totalraisereserve =
        @expression(m, [r in 1:R, t in 1:T, p in 1:P],
                    G > 0 ? sum(ops.raisereserve[r,g,t,p] for g in 1:G) : 0)

    ops.totallowerreserve =
        @expression(m, [r in 1:R, t in 1:T, p in 1:P],
                    G > 0 ? sum(ops.lowerreserve[r,g,t,p] for g in 1:G) : 0)

    # Constraints

    ops.minunitcommitment =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.committed[r,g,t,p] >= 0)

    ops.maxunitcommitment =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.committed[r,g,t,p] <= invs.dispatching[r,g])

    ops.minunitstartups =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.started[r,g,t,p] >= 0)

    ops.minunitshutdowns =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.shutdown[r,g,t,p] >= 0)

    ops.unitcommitmentcontinuity =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.committed[r,g,t,p] ==
                    ops.committed[r,g,prev(1,t,T),p]
                    + ops.started[r,g,t,p] - ops.shutdown[r,g,t,p])

    ops.minunituptime =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    sum(ops.started[r,g,prev(i,t,T),p]
                        for i in 0:(units.minuptime[g]-1)) <=
                    ops.committed[r,g,t,p])

    ops.minunitdowntime =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    sum(ops.shutdown[r,g,prev(i,t,T),p]
                        for i in 0:(units.mindowntime[g]-1)) <=
                    invs.dispatching[r,g] - ops.committed[r,g,t,p])

    ops.mingeneration =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    ops.committed[r,g,t,p] * units.mingen[g])

    ops.maxgeneration =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] + ops.raisereserve[r,g,t,p] <=
                    ops.committed[r,g,t,p] * units.maxgen[g])

    ops.minlowerreserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.lowerreserve[r,g,t,p] >= 0)

    ops.maxlowerreserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.lowerreserve[r,g,t,p] <=
                    ops.committed[r,g,t,p] * units.maxrampdown[g])

    ops.minraisereserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.raisereserve[r,g,t,p] >= 0)

    ops.maxraisereserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.raisereserve[r,g,t,p] <=
                    ops.committed[r,g,t,p] * units.maxrampup[g])

    ops.maxrampdown =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    ops.energydispatch[r,g,prev(1,t,T),p]
                    - (ops.committed[r,g,t,p] - ops.started[r,g,t,p]) *
                      units.maxrampdown[g]
                    + ops.started[r,g,t,p] * units.mingen[g]
                    - ops.shutdown[r,g,t,p] *
                      max(units.mingen[g], units.maxrampdown[g]))

    ops.maxrampup =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] + ops.lowerreserve[r,g,t,p] <=
                    ops.energydispatch[r,g,prev(1,t,T),p]
                    + (ops.committed[r,g,t,p] - ops.started[r,g,t,p]) *
                      units.maxrampup[g]
                    - ops.shutdown[r,g,t,p] * units.mingen[g]
                    + ops.started[r,g,t,p] *
                      max(units.mingen[g], units.maxrampup[g]))

end

welfare(x::ThermalGeneratorOperations) = -sum(x.operatingcosts)
