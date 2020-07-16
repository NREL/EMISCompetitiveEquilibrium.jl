mutable struct StorageOperations{R,G,T,P}

    # Parameters

    fixedcost::Vector{Float64}      # $/unit/investment period, g
    variablecost::Vector{Float64}   # $/MW/hour, g

    # Variables

    energycharge::Array{VariableRef,4} # Withdraw from grid (MW, r x g x t x p)
    energydischarge::Array{VariableRef,4} # Inject to grid (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    fixedcosts::Matrix{ExpressionRef} # ($, r x g)
    variablecosts::Array{ExpressionRef,3} # ($, r x g x p)
    operatingcosts::Matrix{ExpressionRef} # Operating costs ($, r x g)

    stateofcharge::Array{ExpressionRef,4}  # MWh, r x g x t x p

    ucap::Vector{ExpressionRef} # (MW, r)
    totalenergy::Array{ExpressionRef,3} # MW, r x t x p
    totalraisereserve::Array{ExpressionRef,3}
    totallowerreserve::Array{ExpressionRef,3}

    # Constraints

    mindischarge::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxdischarge_power::Array{LessThanConstraintRef,4}
    maxdischarge_energy::Array{LessThanConstraintRef,4}

    mincharge::Array{GreaterThanConstraintRef,4}
    maxcharge_power::Array{LessThanConstraintRef,4}
    maxcharge_energy::Array{LessThanConstraintRef,4}

    minenergy::Array{GreaterThanConstraintRef,4}   # (r x g x t-1 x p)
    maxenergy::Array{LessThanConstraintRef,4}   # (r x g x t-1 x p)

    function StorageOperations{R,T,P}(
        fixedcost::Vector{Float64}, variablecost::Vector{Float64}
    ) where {R,T,P}

        G = length(fixedcost)
        @assert length(variablecost) == G

        new{R,G,T,P}(fixedcost, variablecost)

    end

end

function setup!(
    ops::StorageOperations{R,G,T,P},
    units::StorageDevices{G},
    m::Model,
    invs::ResourceInvestments{R,G},
    periodweights::Vector{Float64}
) where {R,G,T,P}

    regions = 1:R
    gens = 1:G
    timesteps = 1:T
    periods = 1:P

    # Variables

    ops.energydischarge = @variable(m, [regions, gens, timesteps, periods])
    ops.energycharge    = @variable(m, [regions, gens, timesteps, periods])
    ops.raisereserve    = @variable(m, [regions, gens, timesteps, periods])
    ops.lowerreserve    = @variable(m, [regions, gens, timesteps, periods])

    # Expressions

    ops.fixedcosts =
        @expression(m, [r in regions, g in gens],
                    ops.fixedcost[g] * invs.dispatchable[r,g])

    ops.variablecosts =
        @expression(m, [r in regions, g in gens, p in periods],
                    sum(ops.variablecost[g] *
                        (ops.charge[r,g,t,p] + ops.discharge[r,g,t,p])
                        for t in timesteps))

    ops.operatingcosts =
        @expression(m, [r in regions, g in gens],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p]
                        for p in periods))

    ops.ucap =
        @expression(m, [r in regions], G > 0 ? sum(
            invs.dispatchable[r,g] * units.maxgen[g] * units.capacitycredit[g]
        for g in gens) : 0)


    ops.totalenergy =
        @expression(m, [r in regions, t in timesteps, p in periods],
                    G > 0 ? sum(ops.energydischarge[r,g,t,p] - ops.energycharge[r,g,t,p]
                        for g in gens) : 0)

    ops.totalraisereserve =
        @expression(m, [r in regions, t in timesteps, p in periods],
                    G > 0 ? sum(ops.raisereserve[r,g,t,p] for g in gens) : 0)

    ops.totallowerreserve =
        @expression(m, [r in regions, t in timesteps, p in periods],
                    G > 0 ? sum(ops.lowerreserve[r,g,t,p] for g in gens) : 0)

    ops.stateofcharge =
        @expression(m, [r in regions, g in gens, t in timesteps, p in periods],
                    sum(ops.energycharge[r,g,i,p] - ops.energydischarge[r,g,i,p]
                        for i in 1:(t-1)))

    # Constraints
    # TODO: Pull storage reserve constributions from ZMCv2 formulation

    ops.mindischarge =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydischarge[r,g,t,p] >= 0)

    ops.maxdischarge_power =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydischarge[r,g,t,p] <=
                    invs.dispatchable[r,g] * units.maxgen[g])

    ops.maxdischarge_energy =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energydischarge[r,g,t,p] <= ops.stateofcharge[r,g,t,p])

    ops.mincharge =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energycharge[r,g,t,p] >= 0)

    ops.maxcharge_power =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energycharge[r,g,t,p] <=
                    invs.dispatchable[r,g] * units.maxgen[g])

    ops.maxcharge_energy =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.energycharge[r,g,t,p] <=
                    invs.dispatchable[r,g] * units.maxenergy[g]
                     - ops.stateofcharge[r,g,t,p])

    ops.minenergy =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.stateofcharge[r,g,t,p] >= 0)

    ops.maxenergy =
        @constraint(m, [r in regions, g in gens, t in timesteps, p in periods],
                    ops.stateofcharge[r,g,t,p] <=
                    invs.dispatchable[r,g] * units.maxenergy[g])

    # TODO: Periodic SoC boundary conditions?

end

welfare(::StorageOperations) = 0.
