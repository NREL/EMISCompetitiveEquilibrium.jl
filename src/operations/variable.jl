mutable struct VariableGeneratorOperations{R,G,T,P}

    # Parameters

    fixedcost::Vector{Float64}      # $/unit/investment period, g
    variablecost::Vector{Float64}   # $/MW/hour, g
    capacityfactor::Array{Float64,4} # MW, r x g x t x p

    # Variables

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    fixedcosts::Matrix{ExpressionRef} # ($, r x g)
    variablecosts::Array{VariableRef,3} # ($, r x g x p)
    operatingcosts::Matrix{ExpressionRef} # Operating costs ($, r x g)

    ucap::Vector{ExpressionRef} # (MW, r)
    totalenergy::Array{ExpressionRef,3} # MW, r x t x p
    totalraisereserve::Array{ExpressionRef,3}
    totallowerreserve::Array{ExpressionRef,3}

    # Constraints

    mingeneration::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{LessThanConstraintRef,4}
    minlowerreserve::Array{GreaterThanConstraintRef,4}
    maxlowerreserve::Array{LessThanConstraintRef,4}
    minraisereserve::Array{GreaterThanConstraintRef,4}
    maxraisereserve::Array{LessThanConstraintRef,4}

    function VariableGeneratorOperations{R,T,P}(
        fixedcost::Vector{Float64},
        variablecost::Vector{Float64},
        capacityfactor::Array{Float64,4}
    ) where {R,T,P}

        G = length(fixedcost)
        @assert length(variablecost) == G
        @assert size(capacityfactor) == (R, G, T, P)

        new{R,G,T,P}(fixedcost, variablecost, capacityfactor)

    end

end

function setup!(
    ops::VariableGeneratorOperations{R,G,T,P},
    units::VariableGenerators{G},
    m::Model,
    invs::ResourceInvestments{R,G},
    periodweights::Vector{Float64}
) where {R,G,T,P}

    regions = 1:R
    gens = 1:G
    timesteps = 1:T
    periods = 1:P

    # Variables

    ops.energydispatch = @variable(m, [regions, gens, timesteps, periods])
    ops.raisereserve   = @variable(m, [regions, gens, timesteps, periods])
    ops.lowerreserve   = @variable(m, [regions, gens, timesteps, periods])

    # Expressions

    ops.fixedcosts =
        @expression(m, [r in regions, g in gens],
                    ops.fixedcost[g] * invs.dispatchable[r,g])

    ops.variablecosts =
        @expression(m, [r in regions, g in gens, p in periods],
                    sum(ops.variablecost[g] * ops.energydispatch[r,g,t,p]
                        for t in timesteps))

    ops.operatingcosts =
        @expression(m, [r in regions, g in gens],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p] for p in periods))

    ops.ucap =
        @expression(m, [r in regions], 0) # TODO

    ops.totalenergy =
        @expression(m, [r in regions, t in timesteps, p in periods],
                    G > 0 ? sum(ops.energydispatch[r,g,t,p] for g in gens) : 0)

    ops.totalraisereserve =
        @expression(m, [r in regions, t in timesteps, p in periods],
                    G > 0 ? sum(ops.raisereserve[r,g,t,p] for g in gens) : 0)

    ops.totallowerreserve =
        @expression(m, [r in regions, t in timesteps, p in periods],
                    G > 0 ? sum(ops.lowerreserve[r,g,t,p] for g in gens) : 0)

    # Constraints

    ops.mingeneration =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    0)

    ops.maxgeneration =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydispatch[r,g,t,p] + ops.raisereserve[r,g,t,p] <=
                    invs.dispatchable[r,g,t,p] * units.capacityfactor[r,g,t,p] * units.maxgen[g])

    ops.minlowerreserve =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.lowerreserve[r,g,t,p] >= 0)

    ops.maxlowerreserve = # TODO: Is this redundant?
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.lowerreserve[r,g,t,p] <=
                    invs.dispatchable[r,g,t,p] * units.maxgen[g])

    ops.minraisereserve =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.raisereserve[r,g,t,p] >= 0)

    ops.maxraisereserve = # TODO: Is this redundant?
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.raisereserve[r,g,t,p] <=
                    invs.dispatchable[r,g,t,p] * units.maxgen[g])

end

welfare(x::VariableGeneratorOperations) = -sum(x.operatingcosts)
