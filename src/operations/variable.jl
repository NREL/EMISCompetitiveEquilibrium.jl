struct VariableGeneratorsOperations{R,G,T,P}

    # Parameters

    fixedcost::Vector{Float64}      # $/unit/investment period, g
    variablecost::Vector{Float64}   # $/MW/hour, g

    # Variables

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    fixedcosts::Matrix{ExpressionRef} # ($, r x g)
    variablecosts::Array{VariableRef,3} # ($, r x g x p)
    operatingcosts::Matrix{ExpressionRef} # Operating costs ($, r x g)

    ucap::Vector{ExpressionRef} # (MW, r)

    # Constraints

    mingeneration::Array{<:ConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{<:ConstraintRef,4}
    minlowerreserve::Array{<:ConstraintRef,4}
    maxlowerreserve::Array{<:ConstraintRef,4}
    minraisereserve::Array{<:ConstraintRef,4}
    maxraisereserve::Array{<:ConstraintRef,4}

    maxrampdown::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)
    maxrampup::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)

end

function setup!(
    ops::VariableGeneratorOperations{R,G,T,P},
    gens::VariableGenerators{G},
    m::Model,
    invs::ResourceInvestments{R,G},
    periodweights::Vector{Float64}
) where {R,G,T,P}

    regions = 1:R
    gens = 1:G # uh-oh
    timesteps = 1:T
    periods = 1:P

    # Variables

    ops.energydispatch .= @variable(m, [regions, gens, timesteps, periods])
    ops.raisereserve   .= @variable(m, [regions, gens, timesteps, periods])
    ops.lowerreserve   .= @variable(m, [regions, gens, timesteps, periods])

    # Expressions

    ops.fixedcosts .=
        @expression(m, [r in regions, g in gens],
                    ops.fixedcost[g] * invs.dispatchable[r,g])

    ops.variablecosts .=
        @expression(m, [r in regions, g in gens, p in periods],
                    sum(ops.variablecost[g] * ops.energydispatch[r,g,t,p]
                        for t in timesteps)

    ops.operatingcosts .=
        @expression(m, [r in regions, g in gens],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p] for p in periods))

    ops.ucap .=
        @expression(m, [r in regions], 0) # TODO

    # Constraints

    ops.mingeneration .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    0)

    ops.maxgeneration .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydispatch[r,g,t,p] + ops.raisereserve[r,g,t,p] <=
                    invs.dispatchable[r,g,t,p] * gens.maxgen[g])

    ops.minlowerreserve .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.lowerreserve[r,g,t,p] >= 0)

    ops.maxlowerreserve .= # TODO: Is this redundant?
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.lowerreserve[r,g,t,p] <=
                    invs.dispatchable[r,g,t,p] * gens.maxgen[g])

    ops.minraisereserve .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.raisereserve[r,g,t,p] >= 0)

    ops.maxraisereserve .= # TODO: Is this redundant?
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.raisereserve[r,g,t,p] <=
                    invs.dispatchable[r,g,t,p] * gens.maxgen[g])

end

welfare(x::VariableGenerationOperations) = -sum(x.operatingcosts)
