mutable struct VariableGeneratorOperations{R,G,T,P}

    # Parameters

    fixedcost::Matrix{Float64}      # $/unit/investment period, g
    variablecost::Matrix{Float64}   # $/MW/hour, g
    capacityfactor::Array{Float64,4} # MW, r x g x t x p

    # Variables

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    fixedcosts::Matrix{ExpressionRef} # ($, r x g)
    variablecosts::Array{ExpressionRef,3} # ($, r x g x p)
    operatingcosts::Matrix{ExpressionRef} # Operating costs ($, r x g)

    ucap::Vector{ExpressionRef} # (MW, r)
    totalenergy::Array{ExpressionRef,3} # MW, r x t x p
    totalraisereserve::Array{ExpressionRef,3}
    totallowerreserve::Array{ExpressionRef,3}

    # Constraints

    mingeneration::Array{GreaterThanConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{LessThanConstraintRef,4}
    minlowerreserve::Array{GreaterThanConstraintRef,4}
    minraisereserve::Array{GreaterThanConstraintRef,4}

    function VariableGeneratorOperations{}(
        fixedcost::Matrix{Float64},
        variablecost::Matrix{Float64},
        capacityfactor::Array{Float64,4}
    )

        R, G, T, P = size(capacityfactor)

        @assert size(fixedcost) == (R, G)
        @assert size(variablecost) == (R, G)

        new{R,G,T,P}(fixedcost, variablecost, capacityfactor)

    end

end

function VariableGeneratorOperations{T}(
    variablegens::VariableGenerators{G},
    regionlookup::Dict{String,Int}, periodlookup::Dict{String,Int},
    variablepath::String
) where {G,T}

    R = length(regionlookup)
    P = length(periodlookup)
    variablelookup = Dict(zip(variablegens.name, 1:G))

    fixedcost = zeros(Float64, R, G)
    variablecost = zeros(Float64, R, G)
    capacityfactor = zeros(Float64, R, G, T, P)

    variabledata = DataFrame!(CSV.File(joinpath(variablepath, "parameters.csv"),
                                       types=scenarios_resource_param_types))

    for row in eachrow(variabledata)
        gen_idx = variablelookup[row.class]
        region_idx = regionlookup[row.region]
        fixedcost[region_idx, gen_idx] = row.fixedcost
        variablecost[region_idx, gen_idx] = row.variablecost
    end

    availabilitypath = joinpath(variablepath, "availability")

    for classfile in readdir(availabilitypath)

        classmatch = match(r"(.*)\.csv", classfile)
        isnothing(classmatch) && continue 
        class = classmatch[1]

        gen_idx = variablelookup[class]

        availabilitydata = DataFrame!(CSV.File(
            joinpath(availabilitypath, classfile)))

        availabilitydata = stack(availabilitydata, Not([:period,:timestep]),
              variable_name=:region, value_name=:availability)

        for row in eachrow(availabilitydata)

            r_idx = regionlookup[row.region]
            t = row.timestep
            p_idx = periodlookup[row.period]

            capacityfactor[r_idx,gen_idx,t,p_idx] = row.availability

        end

    end

    return VariableGeneratorOperations(fixedcost, variablecost, capacityfactor)

end

function setup!(
    ops::VariableGeneratorOperations{R,G,T,P},
    units::VariableGenerators{G},
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

    ops.energydispatch = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.energydispatch, "energydispatch_variable_$(s.name)", Rs, Gs, Ts, Ps)

    ops.raisereserve   = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.raisereserve, "raisereserve_variable_$(s.name)", Rs, Gs, Ts, Ps)

    ops.lowerreserve   = @variable(m, [1:R, 1:G, 1:T, 1:P])
    varnames!(ops.lowerreserve, "lowerreserve_variable_$(s.name)", Rs, Gs, Ts, Ps)

    # Expressions

    ops.fixedcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcost[r,g] * invs.dispatching[r,g])

    ops.variablecosts =
        @expression(m, [r in 1:R, g in 1:G, p in 1:P],
                    sum(ops.variablecost[r,g] * ops.energydispatch[r,g,t,p]
                        for t in 1:T))

    ops.operatingcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    ops.fixedcosts[r,g] +
                    sum(ops.variablecosts[r,g,p] * periodweights[p] for p in 1:P))

    ops.ucap =
        @expression(m, [r in 1:R], 0) # TODO

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

    ops.mingeneration =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] - ops.lowerreserve[r,g,t,p] >=
                    0)

    ops.maxgeneration =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.energydispatch[r,g,t,p] + ops.raisereserve[r,g,t,p] <=
                    invs.dispatching[r,g] * ops.capacityfactor[r,g,t,p] * units.maxgen[g])

    ops.minlowerreserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.lowerreserve[r,g,t,p] >= 0)

    ops.minraisereserve =
        @constraint(m, [r in 1:R, g in 1:G, t in 1:T, p in 1:P],
                    ops.raisereserve[r,g,t,p] >= 0)

end

welfare(x::VariableGeneratorOperations) = -sum(x.operatingcosts)
