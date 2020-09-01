# R: number of regions
# G: number of generators (either thermal / VG / storage)
# T: number of operations timesteps per period
# P: number of operations periods

mutable struct InvestmentProblem{R,G1,G2,G3,I,T,P} <: AbstractProblem{R,G1,G2,G3,I,T,P}

    model::Model

    technologies::Technologies{G1,G2,G3,I,R}
    initialconditions::InitialConditions{R,G1,G2,G3}

    discountrate::Float64

    rootscenario::Scenario{R,G1,G2,G3,I,T,P}

    InvestmentProblem{T,P}(
        model::Model,
        techs::Technologies{G1,G2,G3,I,R},
        initconds::InitialConditions{R,G1,G2,G3},
        discountrate::Float64
    ) where {R,G1,G2,G3,I,T,P} =
        new{R,G1,G2,G3,I,T,P}(model, techs, initconds, discountrate)

end

function InvestmentProblem(
    techs::Technologies{G1,G2,G3,I,R},
    initconds::InitialConditions{R,G1,G2,G3},
    discountrate::Float64,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,I,T,P},
    markets::Markets{R,T,P},
    periodweights::Vector{Float64},
    optimizer::Type{<:MOI.AbstractOptimizer}
) where {R,G1,G2,G3,I,T,P}

    invprob = InvestmentProblem{T,P}(
        Model(optimizer), techs, initconds, discountrate)

    root = Scenario(invprob, investments, operations, markets, periodweights)
    invprob.rootscenario = root

    return invprob

end

# For now, loading in single-scenario only
function InvestmentProblem(
    folder::String, optimizer::Type{<:MOI.AbstractOptimizer}
)

    # Load representative periods
    perioddata = DataFrame!(CSV.File(joinpath(folder, "periods.csv")))
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

    variabledata = DataFrame!(CSV.File(joinpath(technicalpath, "variable.csv")))
    variabletechs = VariableGenerators(
        variabledata.name, variabledata.owner, variabledata.maxgen)
    n_variables = length(variabletechs.name)

    storagedata = DataFrame!(CSV.File(joinpath(technicalpath, "storage.csv")))
    storagetechs = StorageDevices(
        storagedata.name, storagedata.owner,
        storagedata.maxcharge, storagedata.maxdischarge, storagedata.maxenergy,
        storagedata.chargeefficiency, storagedata.dischargeefficiency,
        storagedata.carryoverefficiency, storagedata.capacitycredit)
    n_storages = length(storagetechs.name)

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
                            types=Dict(:class=>String,:region=>String,
                                       :built=>Int,:optioned=>Int)))
    initialdata.region_idx = getindex.(Ref(regionlookup), initialdata.region)

    thermalstarts = InitialInvestments(
        zeros(Int, n_regions, n_thermals), zeros(Int, n_regions, n_thermals))

    variablestarts = InitialInvestments(
        zeros(Int, n_regions, n_variables), zeros(Int, n_regions, n_variables))

    storagestarts = InitialInvestments(
        zeros(Int, n_regions, n_storages), zeros(Int, n_regions, n_storages))

    for r in eachrow(initialdata)

        thermal_idx = findfirst(isequal(r.class), thermaldata.name)
        if !isnothing(thermal_idx)
            thermalstarts.options[thermal_idx] = r.optioned
            thermalstarts.builds[thermal_idx] = r.built
            continue
        end

        variable_idx = findfirst(isequal(r.class), variabledata.name)
        if !isnothing(variable_idx)
            variablestarts.options[variable_idx] = r.optioned
            variablestarts.builds[variable_idx] = r.built
            continue
        end

        storage_idx = findfirst(isequal(r.class), storagedata.name)
        if !isnothing(storage_idx)
            storagestarts.options[storage_idx] = r.optioned
            storagestarts.builds[storage_idx] = r.built
            continue
        end

        error("Unknown class $(r.class) listed in initial conditions")

    end

    initconds = InitialConditions(thermalstarts, variablestarts, storagestarts)

    # Just load the root scenario for now

    scenariospath = joinpath(folder, "scenarios")
    scenariosdata = DataFrame!(CSV.File(joinpath(scenariospath, "tree.csv"),
                                        types=Dict(:name=>String,
                                                   :parent=>String,
                                                   :probability=>Float64)))

    root_idx = findfirst(ismissing, scenariosdata.parent)
    root_scenario = scenariosdata.name[root_idx]
    rootpath = joinpath(scenariospath, root_scenario)
    investments, operations, markets =
        loadscenario(regionlookup, techs, periodlookup, n_timesteps, rootpath)

    return InvestmentProblem(
        techs, initconds, discountrate,
        investments, operations, markets,
        perioddata.weight, optimizer)

end

function solve!(invprob::InvestmentProblem)
    @objective(invprob.model, Max, welfare(invprob.rootscenario))
    optimize!(invprob.model)
    return
end
