mutable struct StorageOperations{R,G,T,P}

    # Parameters

    fixedcost::Matrix{Float64}      # $/unit/investment period, g
    variablecost::Matrix{Float64}   # $/MW/hour, g

    # Variables

    energycharge::Array{VariableRef,4} # Withdraw from grid (MW, r x g x t x p)
    energydischarge::Array{VariableRef,4} # Inject to grid (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned
    startstateofcharge::Array{VariableRef,3}   # (MWh, r x g x p)

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

    minenergy::Array{GreaterThanConstraintRef,4}   # (r x g x t x p)
    maxenergy::Array{LessThanConstraintRef,4}   # (r x g x t x p)

    minraisereserve::Array{GreaterThanConstraintRef,4}   # (r x g x t x p)
    minlowerreserve::Array{GreaterThanConstraintRef,4}   # (r x g x t x p)

    periodiccharge::Array{EqualToConstraintRef,3} # (r x g x p)

    function StorageOperations{T,P}(
        fixedcost::Matrix{Float64}, variablecost::Matrix{Float64}
    ) where {T,P}

        R, G = size(fixedcost)
        @assert size(variablecost) == (R, G)

        new{R,G,T,P}(fixedcost, variablecost)

    end

end

function StorageOperations{T,P}(
    storages::StorageDevices{G},
    regionlookup::Dict{String,Int}, storagepath::String
) where {G,T,P}

    R = length(regionlookup)
    storagedata = DataFrame!(CSV.File(joinpath(storagepath, "parameters.csv"),
                                      types=scenarios_resource_param_types))

    storagelookup = Dict(zip(storages.name, 1:G))
    fixedcost = zeros(Float64, R, G)
    variablecost = zeros(Float64, R, G)

    for row in eachrow(storagedata)
        stor_idx = storagelookup[row.class]
        region_idx = regionlookup[row.region]
        fixedcost[region_idx, stor_idx] = row.fixedcost
        variablecost[region_idx, stor_idx] = row.variablecost
    end

    return StorageOperations{T,P}(fixedcost, variablecost)

end

function setup!(
    ops::StorageOperations{R,G,T,P},
    units::StorageDevices{G},
    m::Model,
    invs::ResourceInvestments{R,G},
    periodweights::Vector{Float64},
    s::AbstractScenario
) where {R,G,T,P}

    invprob = s.investmentproblem
    Rs = invprob.regionnames
    Gs = units.name
    Ts = string.(1:T)
    Ps = invprob.periodnames

    # Variables

    ops.energydischarge = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.energydischarge, "energydischarge_storage_$(s.name)", Rs, Gs, Ts, Ps)

    ops.energycharge    = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.energycharge, "energycharge_storage_$(s.name)", Rs, Gs, Ts, Ps)

    ops.raisereserve    = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.raisereserve, "raisereserve_storage_$(s.name)", Rs, Gs, Ts, Ps)

    ops.lowerreserve    = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.lowerreserve, "lowerreserve_storage_$(s.name)", Rs, Gs, Ts, Ps)

    ops.startstateofcharge = @variable(m, [1:R, 1:G, 1:P])
    varnames!(ops.startstateofcharge, "startstateofcharge_storage_$(s.name)", Rs, Gs, Ps)

    # Expressions

    ops.fixedcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcost[r,g] * invs.dispatching[r,g])

    ops.variablecosts =
        @expression(m, [r in 1:R, g in 1:G, p in 1:P],
                    sum(ops.variablecost[r,g] *
                        (ops.energycharge[r,g,t,p] + ops.energydischarge[r,g,t,p])
                        for t in 1:T))

    ops.operatingcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p]
                        for p in 1:P))

    ops.ucap =
        @expression(m, [r in 1:R], G > 0 ? sum(
            invs.dispatching[r,g] * units.maxdischarge[g] * units.capacitycredit[g]
        for g in 1:G) : 0)


    ops.totalenergy =
        @expression(m, [r in 1:R, t in 1:T, p in 1:P],
                    G > 0 ? sum(ops.energydischarge[r,g,t,p] - ops.energycharge[r,g,t,p]
                        for g in 1:G) : 0)

    ops.totalraisereserve =
        @expression(m, [r in 1:R, t in 1:T, p in 1:P],
                    G > 0 ? sum(ops.raisereserve[r,g,t,p] for g in 1:G) : 0)

    ops.totallowerreserve =
        @expression(m, [r in 1:R, t in 1:T, p in 1:P],
                    G > 0 ? sum(ops.lowerreserve[r,g,t,p] for g in 1:G) : 0)

    ops.stateofcharge =
        @expression(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.startstateofcharge[r,g,p] +
                    sum(ops.energycharge[r,g,i,p] - ops.energydischarge[r,g,i,p]
                        for i in 1:t))

    # Constraints

    ops.mindischarge =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydischarge[r,g,t,p] >= 0)

    ops.maxdischarge_power =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.raisereserve[r,g,t,p] +
                    ops.energydischarge[r,g,t,p] - ops.energycharge[r,g,t,p] <=
                    invs.dispatching[r,g] * units.maxdischarge[g])

    ops.maxdischarge_energy =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.raisereserve[r,g,t,p] +
                    ops.energydischarge[r,g,t,p] - ops.energycharge[r,g,t,p] <=
                    ops.stateofcharge[r,g,t,p])

    ops.mincharge =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energycharge[r,g,t,p] >= 0)

    ops.maxcharge_power =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.lowerreserve[r,g,t,p] +
                    ops.energycharge[r,g,t,p] - ops.energydischarge[r,g,t,p] <=
                    invs.dispatching[r,g] * units.maxcharge[g])

    ops.maxcharge_energy =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.lowerreserve[r,g,t,p] +
                    ops.energycharge[r,g,t,p] - ops.energydischarge[r,g,t,p] <=
                    invs.dispatching[r,g] * units.maxenergy[g]
                     - ops.stateofcharge[r,g,t,p])

    ops.minraisereserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.raisereserve[r,g,t,p] >= 0)

    ops.minlowerreserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.lowerreserve[r,g,t,p] >= 0)

    ops.minenergy =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.stateofcharge[r,g,t,p] >= 0)

    ops.maxenergy =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.stateofcharge[r,g,t,p] <=
                    invs.dispatching[r,g] * units.maxenergy[g])

    ops.periodiccharge =
        @constraint(m, [r in 1:R, g in 1:G, p in 1:P],
                    ops.stateofcharge[r,g,T,p] == ops.startstateofcharge[r,g,p])

end

welfare(x::StorageOperations) = -sum(x.operatingcosts)
