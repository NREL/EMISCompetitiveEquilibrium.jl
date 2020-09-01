mutable struct ThermalGeneratorOperations{R,G,T,P}

    # Parameters

    fixedcost::Vector{Float64}    # $/unit/investment period, g
    variablecost::Vector{Float64} # $/MW/hour, g
    startupcost::Vector{Float64}  # $/startup/unit, g
    shutdowncost::Vector{Float64} # $/shutdown/unit, g

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
    minunituptime::SparseAxisArray{LessThanConstraintRef,4} # (r x g x t-? x p)
    minunitdowntime::SparseAxisArray{LessThanConstraintRef,4}

    mingeneration::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{LessThanConstraintRef,4}
    minlowerreserve::Array{GreaterThanConstraintRef,4}
    maxlowerreserve::Array{LessThanConstraintRef,4}
    minraisereserve::Array{GreaterThanConstraintRef,4}
    maxraisereserve::Array{LessThanConstraintRef,4}

    maxrampdown::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxrampup::Array{LessThanConstraintRef,4}

    function ThermalGeneratorOperations{R,T,P}(
        fixedcost::Vector{Float64},
        variablecost::Vector{Float64},
        startupcost::Vector{Float64},
        shutdowncost::Vector{Float64}
    ) where {R,T,P}

        G = length(fixedcost)
        @assert length(variablecost) == G
        @assert length(startupcost) == G
        @assert length(shutdowncost) == G

        new{R,G,T,P}(fixedcost, variablecost, startupcost, shutdowncost)

    end

end

function ThermalGeneratorOperations{R,T,P}(
    thermalgens::ThermalGenerators{G}, thermalpath::String
) where {R,G,T,P}

    thermaldata = DataFrame!(CSV.File(joinpath(thermalpath, "parameters.csv")))

    thermallookup = Dict(zip(thermalgens.name, 1:R))
    fixedcost = zeros(Float64, G)
    variablecost = zeros(Float64, G)
    startupcost = zeros(Float64, G)
    shutdowncost = zeros(Float64, G)

    for row in eachrow(thermaldata)
        gen_idx = thermallookup[row.class]
        fixedcost[gen_idx] = row.fixedcost
        variablecost[gen_idx] = row.variablecost
        startupcost[gen_idx] = row.startupcost
        shutdowncost[gen_idx] = row.shutdowncost
    end

    return ThermalGeneratorOperations{R,T,P}(
        fixedcost, variablecost, startupcost, shutdowncost)

end

function setup!(
    ops::ThermalGeneratorOperations{R,G,T,P},
    units::ThermalGenerators{G},
    m::Model, invs::ResourceInvestments{R,G},
    periodweights::Vector{Float64}
) where {R,G,T,P}

    # Variables

    ops.committed = @variable(m, [1:R, 1:G, 1:T, 1:P], Int)
    ops.started   = @variable(m, [1:R, 1:G, 1:T, 1:P], Int)
    ops.shutdown  = @variable(m, [1:R, 1:G, 1:T, 1:P], Int)

    ops.energydispatch = @variable(m, [1:R, 1:G, 1:T, 1:P])
    ops.raisereserve   = @variable(m, [1:R, 1:G, 1:T, 1:P])
    ops.lowerreserve   = @variable(m, [1:R, 1:G, 1:T, 1:P])

    # Expressions

    ops.fixedcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcost[g] * invs.dispatchable[r,g])

    ops.variablecosts =
        @expression(m, [r in 1:R, g in 1:G, p in 1:P],
                    sum(ops.variablecost[g] * ops.energydispatch[r,g,t,p] +
                        ops.startupcost[g] * ops.started[r,g,t,p] +
                        ops.shutdowncost[g] * ops.shutdown[r,g,t,p]
                        for t in 1:T))

    ops.operatingcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p] for p in 1:P))

    ops.ucap =
        @expression(m, [r in 1:R], G > 0 ? sum(
            invs.dispatchable[r,g] * units.maxgen[g] * units.capacitycredit[g]
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
                    ops.committed[r,g,t,p] <= invs.dispatchable[r,g])

    ops.minunitstartups =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.started[r,g,t,p] >= 0)

    ops.maxunitstartups = # Redundant given UC continuity + commitment max?
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.started[r,g,t,p] <=
                    invs.dispatchable[r,g] -
                    ((t > 1) ? ops.committed[r,g,t-1,p] : 0))

    ops.minunitshutdowns =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.shutdown[r,g,t,p] >= 0)

    ops.maxunitshutdowns = # Redundant given UC continuity + commitment max?
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.shutdown[r,g,t,p] <=
                    ((t > 1) ? ops.committed[r,g,t-1,p] : 0))

    ops.unitcommitmentcontinuity =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.committed[r,g,t,p] ==
                    ((t > 1) ? ops.committed[r,g,t-1,p] : 0)
                    + ops.started[r,g,t,p] - ops.shutdown[r,g,t,p])

    ops.minunituptime =
        @constraint(m, [r in 1:R, g in 1:G,
                        t in units.minuptime[g]:T, p in 1:P],
                    sum(ops.started[r,g,i,p]
                        for i in (t-units.minuptime[g]+1):t) <=
                    ops.committed[r,g,t,p])

    ops.minunitdowntime =
        @constraint(m, [r in 1:R, g in 1:G,
                        t in units.mindowntime[g]:T, p in 1:P],
                    sum(ops.shutdown[r,g,i,p]
                        for i in (t-units.mindowntime[g]+1):t) <=
                    invs.dispatchable[r,g] - ops.committed[r,g,t,p])

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

    # TODO: Double-check these constraints make sense

    ops.maxrampdown =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    ((t > 1) ? ops.energydispatch[r,g,t-1,p] : 0)
                    - (ops.committed[r,g,t,p] - ops.started[r,g,t,p]) *
                      units.maxrampdown[g]
                    + ops.started[r,g,t,p] * units.mingen[g]
                    - ops.shutdown[r,g,t,p] *
                      max(units.mingen[g], units.maxrampdown[g]))

    ops.maxrampup =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] + ops.lowerreserve[r,g,t,p] <=
                    ((t > 1) ? ops.energydispatch[r,g,t-1,p] : 0)
                    + (ops.committed[r,g,t,p] - ops.started[r,g,t,p]) *
                      units.maxrampup[g]
                    - ops.shutdown[r,g,t,p] * units.mingen[g]
                    + ops.started[r,g,t,p] *
                      max(units.mingen[g], units.maxrampup[g]))

end

welfare(x::ThermalGeneratorOperations) = -sum(x.operatingcosts)
