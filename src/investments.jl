struct InitialInvestments{R,G}
    options::Matrix{Int} # Existing (buildable) options (r x g)
    builds::Matrix{Int}  # Existing (dispatchable) units

    function InitialInvestments{}(options::Matrix, builds::Matrix)
        R, G = size(options)
        @assert (R, G) == size(builds)
        new{R,G}(options, builds)
    end

end

struct InitialConditions{R,G1,G2,G3}
    thermalgens::InitialInvestments{R,G1}
    variablegens::InitialInvestments{R,G2}
    storages::InitialInvestments{R,G3}
end

mutable struct ResourceInvestments{R,G}

    # Parameters

    # Capital costs are considered sunk and so modeled as one-time expenses,
    # although in terms of cash flow they may actually be amortized over time
    optioncost::Matrix{Float64}     # ($/unit, r x g)
    buildcost::Matrix{Float64}
    retirementcost::Matrix{Float64}

    optionleadtime::Matrix{Int}     # investment periods, r x g
    buildleadtime::Matrix{Int}

    newoptionslimit::Matrix{Int} # investment periods, r x g
    newbuildslimit::Matrix{Int}

    # Variables

    newoptions::Matrix{VariableRef} # New options purchased (r x g)
    newbuilds::Matrix{VariableRef}  # New options exercised / construction starts
    newretirements::Matrix{VariableRef}  # New options exercised / construction starts

    # Expressions

    optionsvested::Matrix{ExpressionRef} # Newly-vested options (r x g)
    buildsfinished::Matrix{ExpressionRef}  # Newly-completed construction

    vesting::Matrix{ExpressionRef} # Options vesting (r x g)
    buildable::Matrix{ExpressionRef} # Units buildable (option vested but not used)
    building::Matrix{ExpressionRef} # Units under construction (option used)
    dispatchable::Matrix{ExpressionRef} # Units dispatchable (finished construction)
    retired::Matrix{ExpressionRef} # Units retired

    ucap::Matrix{ExpressionRef} # Unforced dispatchable capacity (MW, r x g)

    investmentcosts::Matrix{ExpressionRef} # $, r x g

    # Constraints
    minnewoptions::Matrix{GreaterThanConstraintRef} # r x g
    maxnewoptions::Matrix{LessThanConstraintRef}
    minnewbuilds::Matrix{GreaterThanConstraintRef}
    maxnewbuilds_optionlimit::Matrix{LessThanConstraintRef}
    maxnewbuilds_physicallimit::Matrix{LessThanConstraintRef}

    function ResourceInvestments{}(
        optioncost::Matrix{Float64}, buildcost::Matrix{Float64},
        retirementcost::Matrix{Float64},
        optionleadtime::Matrix{Int}, buildleadtime::Matrix{Int},
        maxnewoptions::Matrix{Int}, maxnewbuilds::Matrix{Int})

        R, G = size(maxnewoptions)
        @assert size(maxnewbuilds) == (R,G)

        @assert size(optioncost) == (R,G)
        @assert size(buildcost) == (R,G)
        @assert size(retirementcost) == (R,G)

        @assert size(optionleadtime) == (R,G)
        @assert size(buildleadtime) == (R,G)

        @assert size(maxnewoptions) == (R,G)

        new{R,G}(optioncost, buildcost, retirementcost,
                 optionleadtime, buildleadtime,
                 maxnewoptions, maxnewbuilds)

    end

end

function ResourceInvestments(
    tech::AbstractTechnology{G},
    regionlookup::Dict{String,Int},
    resourcetypefolder::String
) where G

    R = length(regionlookup)
    techdata = DataFrame!(CSV.File(joinpath(resourcetypefolder, "parameters.csv"),
                                   types=scenarios_resource_param_types))
    genlookup = Dict(zip(tech.name, 1:G))

    optioncost = zeros(Float64, R, G)
    buildcost = zeros(Float64, R, G)
    retirementcost = zeros(Float64, R, G)

    optionleadtime = zeros(Int, R, G)
    buildleadtime = zeros(Int, R, G)

    newoptionslimit = zeros(Int, R, G)
    newbuildslimit = zeros(Int, R, G)

    for row in eachrow(techdata)

        region_idx = regionlookup[row.region]
        gen_idx = genlookup[row.class]

        optioncost[region_idx, gen_idx] = row.optioncost
        buildcost[region_idx, gen_idx] = row.buildcost
        retirementcost[region_idx, gen_idx] = row.retirementcost

        optionleadtime[region_idx, gen_idx] = row.optionleadtime
        buildleadtime[region_idx, gen_idx] = row.buildleadtime

        newoptionslimit[region_idx, gen_idx] = row.newoptionslimit
        newbuildslimit[region_idx, gen_idx] = row.newbuildslimit

    end

    return ResourceInvestments(
        optioncost, buildcost, retirementcost,
        optionleadtime, buildleadtime,
        newoptionslimit, newbuildslimit)

end

function setup!(
    s::AbstractScenario,
    invtype::Symbol,
    m::Model,
    initconds::InitialInvestments{R,G}
) where {R, G}

    invs = getfield(s.investments, invtype)

    # Variables

    invs.newoptions = @variable(m, [1:R, 1:G], Int)
    invs.newbuilds = @variable(m, [1:R, 1:G], Int)
    invs.newretirements = @variable(m, [1:R, 1:G], Int)

    # Expressions

    invs.optionsvested =
        @expression(m, [r in 1:R, g in 1:G],
                    maturing(s, r, g, invtype, :optionleadtime, :newoptions))

    invs.buildsfinished =
        @expression(m, [r in 1:R, g in 1:G],
                    maturing(s, r, g, invtype, :buildleadtime, :newbuilds))

    if isnothing(s.parent)
        setup_unitstates!(invs, m, initconds)
    else
        setup_unitstates!(invs, m, s.parent)
    end

    invs.investmentcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    invs.optioncost[r,g] * invs.newoptions[r,g] +
                    invs.buildcost[r,g] * invs.newbuilds[r,g] +
                    invs.retirementcost[r,g] * invs.newretirements[r,g])

    # Constraints

    invs.minnewoptions =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.newoptions[r,g] >= 0)

    invs.maxnewoptions =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.newoptions[r,g] <= invs.newoptionslimit[r,g])

    invs.minnewbuilds =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.newbuilds[r,g] >= 0)

    invs.maxnewbuilds_optionlimit =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.newbuilds[r,g] <= invs.buildable[r,g])

    invs.maxnewbuilds_physicallimit =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.newbuilds[r,g] <= invs.newbuildslimit[r,g])

    return

end

function setup_unitstates!(
    invs::ResourceInvestments{R,G},
    m::Model,
    existing::InitialInvestments{R,G}
) where {R, G}

    invs.vesting =
        @expression(m, [r in 1:R, g in 1:G],
                    0 + invs.newoptions[r,g]
                    - invs.optionsvested[r,g])

    invs.buildable =
        @expression(m, [r in 1:R, g in 1:G],
                    existing.options[r,g] + invs.optionsvested[r,g]
                    - invs.newbuilds[r,g])

    invs.building =
        @expression(m, [r in 1:R, g in 1:G],
                    0 + invs.newbuilds[r,g]
                    - invs.buildsfinished[r,g])

    invs.dispatchable =
        @expression(m, [r in 1:R, g in 1:G],
                    existing.builds[r,g] + invs.buildsfinished[r,g]
                    - invs.newretirements[r,g])

    invs.retired =
        @expression(m, [r in 1:R, g in 1:G],
                    0 + invs.newretirements[r,g])

end

function setup_unitstates!(
    invs::ResourceInvestments{R,G},
    m::Model,
    parentinvs::ResourceInvestments{R,G}
) where {R, G}

    invs.vesting =
        @expression(m, [r in 1:R, g in 1:G],
                    parentinvs.vesting[r,g] + invs.newoptions[r,g]
                    - invs.optionsvested[r,g])

    invs.buildable =
        @expression(m, [r in 1:R, g in 1:G],
                    parentinvs.buildable[r,g] + invs.optionsvested[r,g]
                    - invs.newbuilds[r,g])

    invs.building =
        @expression(m, [r in 1:R, g in 1:G],
                    parentinvs.building + invs.newbuilds[r,g]
                    - invs.buildsfinished[r,g])

    invs.dispatchable =
        @expression(m, [r in 1:R, g in 1:G],
                    parentinvs.dispatchable[r,g] + invs.buildsfinished[r,g]
                    - invs.newretirements[r,g])

    invs.retired =
        @expression(m, [r in 1:R, g in 1:G],
                    parentinvs.retired[r,g] + invs.newretirements[r,g])

end

welfare(x::ResourceInvestments) = -sum(x.investmentcosts)


struct Investments{R,G1,G2,G3}
    thermalgens::ResourceInvestments{R,G1}
    variablegens::ResourceInvestments{R,G2}
    storages::ResourceInvestments{R,G3}
end

function loadinvestments(
    techs::Technologies, regions::Dict{String,Int}, resourcepath::String)

    thermal =
        ResourceInvestments(techs.thermal, regions,
                            joinpath(resourcepath, "thermal"))
    variable =
        ResourceInvestments(techs.variable, regions,
                            joinpath(resourcepath, "variable"))
    storage =
        ResourceInvestments(techs.storage, regions,
                            joinpath(resourcepath, "storage"))

    return Investments(thermal, variable, storage)

end

welfare(x::Investments) =
    welfare(x.thermalgens) + welfare(x.variablegens) + welfare(x.storages)
