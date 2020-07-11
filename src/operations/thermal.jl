struct ThermalGeneratorOperations{R,G,T,P}

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
    maxunitstartups::Array{LessThanConstraintRef,4}   # (r x g x t-1 x p)
    minunitshutdowns::Array{GreaterThanConstraintRef,4}  # (r x g x t x p)
    maxunitshutdowns::Array{LessThanConstraintRef,4}  # (r x g x t-1 x p)

    unitcommitmentcontinuity::Array{EqualToConstraintRef,4}  # (r x g x t-1 x p)
    minunituptime::Array{LessThanConstraintRef,4} # (r x g x t-? x p)
    minunitdowntime::Array{LessThanConstraintRef,4}

    mingeneration::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{LessThanConstraintRef,4}
    minlowerreserve::Array{GreaterThanConstraintRef,4}
    maxlowerreserve::Array{LessThanConstraintRef,4}
    minraisereserve::Array{GreaterThanConstraintRef,4}
    maxraisereserve::Array{LessThanConstraintRef,4}

    maxrampdown::Array{GreaterThanConstraintRef,4} # (r x g x t-1 x p)
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

        new{R,G,T,P}(

            fixedcost, variablecost, startupcost, shutdowncost,

            Array{VariableRef}(undef,R,G,T,P),
            Array{VariableRef}(undef,R,G,T,P),
            Array{VariableRef}(undef,R,G,T,P),

            Array{VariableRef}(undef,R,G,T,P),
            Array{VariableRef}(undef,R,G,T,P),
            Array{VariableRef}(undef,R,G,T,P),

            Array{ExpressionRef}(undef,R,G),
            Array{ExpressionRef}(undef,R,G,P),
            Array{ExpressionRef}(undef,R,G),

            Array{ExpressionRef}(undef,R),
            Array{ExpressionRef}(undef,R,T,P),
            Array{ExpressionRef}(undef,R,T,P),
            Array{ExpressionRef}(undef,R,T,P),

            Array{GreaterThanConstraintRef}(undef,R,G,T,P),
            Array{LessThanConstraintRef}(undef,R,G,T,P),
            Array{GreaterThanConstraintRef}(undef,R,G,T,P),
            Array{LessThanConstraintRef}(undef,R,G,T-1,P),
            Array{GreaterThanConstraintRef}(undef,R,G,T,P),
            Array{LessThanConstraintRef}(undef,R,G,T-1,P),

            Array{EqualToConstraintRef}(undef,R,G,T-1,P),
            Array{LessThanConstraintRef}(undef,R,G,T-i,P),
            Array{LessThanConstraintRef}(undef,R,G,T-i,P),

            Array{GreaterThanConstraintRef}(undef,R,G,T,P),
            Array{LessThanConstraintRef}(undef,R,G,T,P),
            Array{GreaterThanConstraintRef}(undef,R,G,T,P),
            Array{LessThanConstraintRef}(undef,R,G,T,P),
            Array{GreaterThanConstraintRef}(undef,R,G,T,P),
            Array{LessThanConstraintRef}(undef,R,G,T,P),

            Array{GreaterThanConstraintRef}(undef,R,G,T-1,P),
            Array{LessThanConstraintRef}(undef,R,G,T-1,P)

        )

    end

end

function setup!(
    ops::ThermalGeneratorOperations{R,G,T,P},
    gens::ThermalGenerators{G},
    m::Model, invs::ResourceInvestments{R,G},
    periodweights::Vector{Float64}
) where {R,G,T,P}

    regions = 1:R
    gens = 1:G
    timesteps = 1:T
    periods = 1:P

    # Variables

    ops.committed .= @variable(m, [regions, gens, timesteps, periods], Int)
    ops.started   .= @variable(m, [regions, gens, timesteps, periods], Int)
    ops.shutdown  .= @variable(m, [regions, gens, timesteps, periods], Int)

    ops.energydispatch .= @variable(m, [regions, gens, timesteps, periods])
    ops.raisereserve   .= @variable(m, [regions, gens, timesteps, periods])
    ops.lowerreserve   .= @variable(m, [regions, gens, timesteps, periods])

    # Expressions

    ops.fixedcosts .=
        @expression(m, [r in regions, g in gens],
                    ops.fixedcost[g] * invs.dispatchable[r,g])

    ops.variablecosts .=
        @expression(m, [r in regions, g in gens, p in periods],
                    sum(ops.variablecost[g] * ops.energydispatch[r,g,t,p] +
                        ops.startupcost[g] * ops.started[r,g,t,p] +
                        ops.shutdowncost[g] * ops.shutdown[r,g,t,p]
                        for t in timesteps))

    ops.operatingcosts .=
        @expression(m, [r in regions, g in gens],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p] for p in periods))

    ops.ucap .=
        @expression(m, [r in regions], sum(
            invs.dispatchable[r,g] * gens.maxgen[g] * gens.capacitycredit[g]
        for g in gens))

    ops.totalenergy .=
        @expression(m, [r in regions, t in timesteps, p in periods],
                    sum(ops.energydispatch[r,g,t,p] for g in gens))

    ops.totalraisereserve .=
        @expression(m, [r in regions, t in timesteps, p in periods],
                    sum(ops.raisereserve[r,g,t,p] for g in gens))

    ops.totallowerreserve .=
        @expression(m, [r in regions, t in timesteps, p in periods],
                    sum(ops.lowerreserve[r,g,t,p] for g in gens))

    # Constraints

    ops.minunitcommitment .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    invs.committed[r,g,t,p] >= 0)

    ops.maxunitcommitment .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    invs.committed[r,g,t,p] <= invs.dispatchable[r,g])

    ops.minstartup .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.started[r,g,t,p] >= 0)

    ops.maxstartup .= # Redundant given UC continuity + commitment max?
        @constraint(m, [r in regions, g in gens, t in 2:T, p in periods],
                    ops.started[r,g,t,p] <=
                    invs.dispatchable[r,g] - ops.committed[r,g,t-1,p])

    ops.minshutdown .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.shutdown[r,g,t,p] >= 0)

    ops.maxshutdown .= # Redundant given UC continuity + commitment max?
        @constraint(m, [r in regions, g in gens, t in 2:T, p in periods],
                    ops.shutdown[r,g,t,p] <= ops.committed[r,g,t-1,p])

    ops.unitcommitmentcontinuity .=
        @constraint(m, [r in regions, g in gens, t in 2:T, p in periods],
                    ops.committed[r,g,t,p] == ops.committed[r,g,t-1,p]
                    + ops.startup[r,g,t,p] - ops.shutdown[r,g,t,p])

    ops.minunituptime .=
        @constraint(m, [r in regions, g in gens,
                        t in gens.minuptime[g]:T, p in periods],
                    sum(ops.startup[r,g,i,p]
                        for i in (t-gens.minuptime[g]+1):t) <=
                    ops.committed[r,g,t,p])

    ops.minunitdowntime .=
        @constraint(m, [r in regions, g in gens,
                        t in gens.mindowntime[g]:T, p in periods],
                    sum(ops.shutdown[r,g,i,p]
                        for i in (t-gens.mindowntime[g]+1):t) <=
                    unitsdispatchable[r,g] - ops.committed[r,g,t,p])

    ops.mingeneration .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    ops.committed[r,g,t,p] * gens.mingen[g])

    ops.maxgeneration .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydispatch[r,g,t,p] + ops.raisereserve[r,g,t,p] <=
                    ops.committed[r,g,t,p] * gens.maxgen[g])

    ops.minlowerreserve .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.lowerreserve[r,g,t,p] >= 0)

    ops.maxlowerreserve .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.lowerreserve[r,g,t,p] <=
                    ops.committed[r,g,t,p] * gens.maxrampdown[g])

    ops.minraisereserve .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.raisereserve[r,g,t,p] >= 0)

    ops.maxraisereserve .=
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.raisereserve[r,g,t,p] <=
                    ops.committed[r,g,t,p] * gens.maxrampup[g])

    # TODO: Double check these constraints make sense

    ops.maxrampdown .=
        @constraint(m, [r in regions, g in gens, t in 2:T, p in periods],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    ops.energydispatch[r,g,t-1,p]
                    - (ops.committed[r,g,t,p] - ops.startup[r,g,t,p]) *
                      gens.maxrampdown[g]
                    + ops.startup[r,g,t,p] * gens.mingen[g]
                    - ops.shutdown[r,g,t,p] *
                      max(gens.mingen[g], gens.maxrampdown[g]))

    ops.maxrampup .=
        @constraint(m, [r in regions, g in gens, t in 2:T, p in periods],
                    ops.energydispatch[r,g,t,p] + ops.lowerreserve[r,g,t,p] <=
                    ops.energydispatch[r,g,t-1,p]
                    + (ops.committed[r,g,t,p] - ops.startup[r,g,t,p]) *
                      gens.maxrampup[g]
                    - ops.shutdown[r,g,t,p] * gens.mingen[g]
                    + ops.startup[r,g,t,p] *
                      max(gens.mingen[g], gens.maxrampup[g]))

end

welfare(x::ThermalGeneratorOperations) = -sum(x.operatingcosts)
