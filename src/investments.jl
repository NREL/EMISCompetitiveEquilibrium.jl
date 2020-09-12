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
    thermal::InitialInvestments{R,G1}
    variable::InitialInvestments{R,G2}
    storage::InitialInvestments{R,G3}
end

mutable struct ResourceInvestments{R,G}

    # Unit state machine:
    # --> vesting --> building --> retired
    #            \      ^     \       ^
    #             \     |      \      |
    #              > holding    > dispatching

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
    newforcedretirements::Matrix{Int}

    # Variables

    newoptions::Matrix{VariableRef} # New options purchased (r x g)
    newholding::Matrix{VariableRef} # Hold a newly-vested option
    newbuilds_vesting::Matrix{VariableRef}  # Excercise a newly-vested option
    newbuilds_holding::Matrix{VariableRef} # Start construction on held project
    newdispatching::Matrix{VariableRef} # Start dispatching newly-constructed units
    newretirements_dispatching::Matrix{VariableRef}  # Retire a dispatchable unit
    newretirements_building::Matrix{VariableRef}  # Retire a newly-constructed unit

    # Expressions

    optionsvested::Matrix{ExpressionRef} # Newly-vested options (r x g)
    buildsstarted::Matrix{ExpressionRef}  # Newly-started construction
    buildsfinished::Matrix{ExpressionRef}  # Newly-completed construction
    newretirements::Matrix{ExpressionRef}  # New retirements

    vesting::Matrix{ExpressionRef} # Options vesting (r x g)
    holding::Matrix{ExpressionRef} # Units buildable (option vested but not used)
    building::Matrix{ExpressionRef} # Units under construction (option used)
    dispatching::Matrix{ExpressionRef} # Units dispatchable (finished construction)
    retired::Matrix{ExpressionRef} # Units retired

    totalforcedretirements::Matrix{ExpressionRef} # Minimum cumulative units retired

    ucap::Matrix{ExpressionRef} # Unforced dispatchable capacity (MW, r x g)

    investmentcosts::Matrix{ExpressionRef} # $, r x g

    # Constraints

    minnewoptions::Matrix{GreaterThanConstraintRef} # r x g
    maxnewoptions::Matrix{LessThanConstraintRef}

    minnewholding::Matrix{GreaterThanConstraintRef}

    minnewbuilds_vesting::Matrix{GreaterThanConstraintRef}
    minnewbuilds_holding::Matrix{GreaterThanConstraintRef}
    maxnewbuilds::Matrix{LessThanConstraintRef}

    minnewdispatching::Matrix{GreaterThanConstraintRef}

    minnewretirements_dispatching::Matrix{GreaterThanConstraintRef}
    minnewretirements_building::Matrix{GreaterThanConstraintRef}

    optionsvested_balance::Matrix{EqualToConstraintRef}
    buildsfinished_balance::Matrix{EqualToConstraintRef}

    minvesting::Matrix{GreaterThanConstraintRef}
    minholding::Matrix{GreaterThanConstraintRef}
    minbuilding::Matrix{GreaterThanConstraintRef}
    mindispatching::Matrix{GreaterThanConstraintRef}
    minretired::Matrix{GreaterThanConstraintRef}

    mintotalretirements::Matrix{GreaterThanConstraintRef}

    function ResourceInvestments{}(
        optioncost::Matrix{Float64}, buildcost::Matrix{Float64},
        retirementcost::Matrix{Float64},
        optionleadtime::Matrix{Int}, buildleadtime::Matrix{Int},
        maxnewoptions::Matrix{Int}, maxnewbuilds::Matrix{Int},
        forcedretirements::Matrix{Int})

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
                 maxnewoptions, maxnewbuilds, forcedretirements)

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
    newforcedretirements = zeros(Int, R, G)

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
        newforcedretirements[region_idx, gen_idx] = row.newforcedretirements

    end

    return ResourceInvestments(
        optioncost, buildcost, retirementcost,
        optionleadtime, buildleadtime,
        newoptionslimit, newbuildslimit, newforcedretirements)

end

function setup!(
    s::AbstractScenario,
    invtype::Symbol,
    m::Model,
    initconds::InitialInvestments{R,G}
) where {R, G}

    invprob = s.investmentproblem
    Rs = invprob.regionnames
    Gs = getfield(invprob.technologies, invtype).name

    invs = getfield(s.investments, invtype)

    # Variables

    invs.newoptions = @variable(m, [1:R, 1:G], Int)
    varnames!(invs.newoptions, "newoptions_$(invtype)_$(s.name)", Rs, Gs)

    invs.newholding = @variable(m, [1:R, 1:G], Int)
    varnames!(invs.newholding, "newholding_$(invtype)_$(s.name)", Rs, Gs)

    invs.newbuilds_vesting = @variable(m, [1:R, 1:G], Int)
    varnames!(invs.newbuilds_vesting, "newbuilds_vesting_$(invtype)_$(s.name)", Rs, Gs)

    invs.newbuilds_holding = @variable(m, [1:R, 1:G], Int)
    varnames!(invs.newbuilds_holding, "newbuilds_holding_$(invtype)_$(s.name)", Rs, Gs)

    invs.newdispatching = @variable(m, [1:R, 1:G], Int)
    varnames!(invs.newdispatching, "newdispatching_$(invtype)_$(s.name)", Rs, Gs)

    invs.newretirements_dispatching = @variable(m, [1:R, 1:G], Int)
    varnames!(invs.newretirements_dispatching, "newretirements_dispatching_$(invtype)_$(s.name)", Rs, Gs)

    invs.newretirements_building = @variable(m, [1:R, 1:G], Int)
    varnames!(invs.newretirements_building, "newretirements_building_$(invtype)_$(s.name)", Rs, Gs)

    # Expressions

    invs.optionsvested = @expression(m, [r in 1:R, g in 1:G],
        invs.newholding[r,g] + invs.newbuilds_vesting[r,g])

    invs.buildsstarted = @expression(m, [r in 1:R, g in 1:G],
        invs.newbuilds_holding[r,g] + invs.newbuilds_vesting[r,g])

    invs.buildsfinished = @expression(m, [r in 1:R, g in 1:G],
        invs.newretirements_building[r,g] + invs.newdispatching[r,g])


    invs.newretirements = @expression(m, [r in 1:R, g in 1:G],
        invs.newretirements_dispatching[r,g] + invs.newretirements_building[r,g])

    invs.vesting = @expression(m, [r in 1:R, g in 1:G],
        invs.newoptions[r,g] - invs.optionsvested[r,g])

    invs.holding = @expression(m, [r in 1:R, g in 1:G],
        invs.newholding[r,g] - invs.newbuilds_holding[r,g])

    invs.building = @expression(m, [r in 1:R, g in 1:G],
        invs.buildsstarted[r,g] - invs.buildsfinished[r,g])

    invs.dispatching = @expression(m, [r in 1:R, g in 1:G],
        invs.newdispatching[r,g] - invs.newretirements_dispatching[r,g])

    invs.retired = @expression(m, [r in 1:R, g in 1:G],
        invs.newretirements[r,g])

    invs.totalforcedretirements = @expression(m, [r in 1:R, g in 1:G],
        invs.newforcedretirements[r,g])

    if isnothing(s.parent)
        invs.holding .+= initconds.options
        invs.dispatching .+= initconds.builds
    else
        parentinvs = getfield(s.parent.investments, invtype)
        invs.vesting .+= parentinvs.vesting
        invs.holding .+= parentinvs.holding
        invs.building .+= parentinvs.building
        invs.dispatching .+= parentinvs.dispatching
        invs.retired .+= parentinvs.retired
        invs.totalforcedretirements .+= parentinvs.totalforcedretirements
    end

    invs.investmentcosts =
        @expression(m, [r in 1:R, g in 1:G],
                    invs.optioncost[r,g] * invs.newoptions[r,g] +
                    invs.buildcost[r,g] * invs.buildsstarted[r,g] +
                    invs.retirementcost[r,g] * invs.newretirements[r,g])

    # Constraints

    for field in [:newoptions, :newholding, :newbuilds_vesting, :newbuilds_holding,
                  :newdispatching, :newretirements_dispatching, :newretirements_building,
                  :vesting, :holding, :building, :dispatching, :retired]

        setfield!(invs, Symbol(:min, field),
            @constraint(m, [r in 1:R, g in 1:G],
                        getfield(invs, field)[r,g] >= 0))

    end

    invs.maxnewoptions =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.newoptions[r,g] <= invs.newoptionslimit[r,g])

    invs.maxnewbuilds =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.buildsstarted[r,g] <= invs.newbuildslimit[r,g])


    invs.optionsvested_balance = @constraint(m, [r in 1:R, g in 1:G],
        invs.optionsvested[r,g] ==
        maturing(s, r, g, invtype, :optionleadtime, :newoptions))

    invs.buildsfinished_balance = @constraint(m, [r in 1:R, g in 1:G],
        invs.buildsfinished[r,g] ==
        maturing(s, r, g, invtype, :buildleadtime, :buildsstarted))

    invs.mintotalretirements =
        @constraint(m, [r in 1:R, g in 1:G],
                    invs.retired[r,g] >= invs.totalforcedretirements[r,g])

    return

end

welfare(x::ResourceInvestments) = -sum(x.investmentcosts)


struct Investments{R,G1,G2,G3}
    thermal::ResourceInvestments{R,G1}
    variable::ResourceInvestments{R,G2}
    storage::ResourceInvestments{R,G3}
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

welfare(inv::Investments) =
    welfare(inv.thermal) + welfare(inv.variable) + welfare(inv.storage)
