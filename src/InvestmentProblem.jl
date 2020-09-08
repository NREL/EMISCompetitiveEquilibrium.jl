# R: number of regions
# G: number of generators (either thermal / VG / storage)
# T: number of operations timesteps per period
# P: number of operations periods (representative)

mutable struct InvestmentProblem{R,G1,G2,G3,I,T,P} <: AbstractProblem{R,G1,G2,G3,I,T,P}

    model::Model
    regionnames::Vector{String}
    periodnames::Vector{String}
    technologies::Technologies{G1,G2,G3,I,R}
    initialconditions::InitialConditions{R,G1,G2,G3}
    discountrate::Float64
    rootscenario::Scenario{R,G1,G2,G3,I,T,P}

    function InvestmentProblem{T}(
        model::Model,
        regionnames::Vector{String},
        periodnames::Vector{String},
        techs::Technologies{G1,G2,G3,I,R},
        initconds::InitialConditions{R,G1,G2,G3},
        discountrate::Float64
    ) where {R,G1,G2,G3,I,T}

        @assert R == length(regionnames)
        P = length(periodnames)

        new{R,G1,G2,G3,I,T,P}(model, regionnames, periodnames,
                              techs, initconds, discountrate)

    end

end

function InvestmentProblem(
    regionnames::Vector{String},
    periodnames::Vector{String},
    techs::Technologies{G1,G2,G3,I,R},
    initconds::InitialConditions{R,G1,G2,G3},
    discountrate::Float64,
    rootname::String,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,I,T,P},
    markets::Markets{R,T,P},
    periodweights::Vector{Float64},
    optimizer::Optimizer
) where {R,G1,G2,G3,I,T,P}

    invprob = InvestmentProblem{T}(
        Model(optimizer), regionnames, periodnames,
        techs, initconds, discountrate)

    root = Scenario(invprob, rootname,
                    investments, operations, markets, periodweights)
    invprob.rootscenario = root

    return invprob

end

# For now, loading in single-scenario only
function InvestmentProblem(
    folder::String, optimizer::Optimizer
)

    # Load representative periods
    perioddata = DataFrame!(CSV.File(joinpath(folder, "periods.csv"),
                                     types=period_types))
    n_periods = length(perioddata.name)
    periodlookup = Dict(zip(perioddata.name, 1:n_periods))

    technicalpath = joinpath(folder, "technical")

    n_timesteps = 24 # TODO: Load these from a file
    discountrate = 0.95

    # Load regions

    regiondata = DataFrame!(CSV.File(joinpath(technicalpath, "regions.csv"),
                                     type=String))
    n_regions = length(regiondata.name)
    regionlookup = Dict(zip(regiondata.name, 1:n_regions))

    # Load technologies

    thermaldata = DataFrame!(CSV.File(joinpath(technicalpath, "thermal.csv")))
    thermaltechs = ThermalGenerators(
        thermaldata.name, thermaldata.owner,
        thermaldata.mingen, thermaldata.maxgen,
        thermaldata.minuptime, thermaldata.mindowntime,
        thermaldata.maxrampup, thermaldata.maxrampdown,
        thermaldata.capacitycredit)
    n_thermals = length(thermaltechs.name)
    thermallookup = Dict(zip(thermaldata.name, 1:n_thermals))

    variabledata = DataFrame!(CSV.File(joinpath(technicalpath, "variable.csv")))
    variabletechs = VariableGenerators(
        variabledata.name, variabledata.owner, variabledata.maxgen)
    n_variables = length(variabletechs.name)
    variablelookup = Dict(zip(variabledata.name, 1:n_variables))

    storagedata = DataFrame!(CSV.File(joinpath(technicalpath, "storage.csv")))
    storagetechs = StorageDevices(
        storagedata.name, storagedata.owner,
        storagedata.maxcharge, storagedata.maxdischarge, storagedata.maxenergy,
        storagedata.chargeefficiency, storagedata.dischargeefficiency,
        storagedata.carryoverefficiency, storagedata.capacitycredit)
    n_storages = length(storagetechs.name)
    storagelookup = Dict(zip(storagedata.name, 1:n_storages))

    interfacedata = DataFrame!(CSV.File(
        joinpath(technicalpath, "interface.csv"), type=String))

    from_idx = getindex.(Ref(regionlookup), interfacedata.from)
    to_idx = getindex.(Ref(regionlookup), interfacedata.to)
    interfaces = Interfaces{n_regions}(
        interfacedata.name, tuple.(from_idx, to_idx))
    n_interfaces = length(interfacedata.name)

    techs = Technologies(thermaltechs, variabletechs, storagetechs, interfaces)

    # Load starting builds / options

    initialdata =
        DataFrame!(CSV.File(joinpath(folder, "initialconditions.csv"),
                            types=initialcondition_types))

    thermalstarts = InitialInvestments(
        zeros(Int, n_regions, n_thermals), zeros(Int, n_regions, n_thermals))

    variablestarts = InitialInvestments(
        zeros(Int, n_regions, n_variables), zeros(Int, n_regions, n_variables))

    storagestarts = InitialInvestments(
        zeros(Int, n_regions, n_storages), zeros(Int, n_regions, n_storages))

    for r in eachrow(initialdata)

        region_idx = regionlookup[r.region]

        thermal_idx = get(thermallookup, r.class, nothing)
        if !isnothing(thermal_idx)
            thermalstarts.options[region_idx, thermal_idx] = r.optioned
            thermalstarts.builds[region_idx, thermal_idx] = r.built
            continue
        end

        variable_idx = get(variablelookup, r.class, nothing)
        if !isnothing(variable_idx)
            variablestarts.options[region_idx, variable_idx] = r.optioned
            variablestarts.builds[region_idx, variable_idx] = r.built
            continue
        end

        storage_idx = get(storagelookup, r.class, nothing)
        if !isnothing(storage_idx)
            storagestarts.options[region_idx, storage_idx] = r.optioned
            storagestarts.builds[region_idx, storage_idx] = r.built
            continue
        end

        error("Unknown class $(r.class) listed in initial conditions")

    end

    initconds = InitialConditions(thermalstarts, variablestarts, storagestarts)

    # Just load the root scenario for now

    scenariospath = joinpath(folder, "scenarios")
    scenariosdata = DataFrame!(CSV.File(joinpath(scenariospath, "tree.csv"),
                                        types=scenarios_tree_types))

    root_idx = findfirst(ismissing, scenariosdata.parent)
    rootname = scenariosdata.name[root_idx]
    rootpath = joinpath(scenariospath, rootname)
    investments, operations, markets =
        loadscenario(regionlookup, techs, periodlookup, n_timesteps, rootpath)

    return InvestmentProblem(
        regiondata.name, perioddata.name, techs, initconds, discountrate,
        rootname, investments, operations, markets,
        perioddata.weight, optimizer)

end

function solve!(invprob::InvestmentProblem)
    @objective(invprob.model, Max, welfare(invprob.rootscenario))
    optimize!(invprob.model)
    return
end

# TODO: Breadth-first search might be more useful (keep things chronological?)

scenarios(invprob::InvestmentProblem) = scenarios(invprob.rootscenario)

function scenarios(root::Scenario)
    iszero(length(root.children)) && return [(root, true)]
    return vcat((root, false), scenarios.(root.children)...)
end
