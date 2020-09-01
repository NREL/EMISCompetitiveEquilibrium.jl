include("thermal.jl")
include("variable.jl")
include("storage.jl")
include("transmission.jl")

struct Operations{R,G1,G2,G3,I,T,P}
    thermalgens::ThermalGeneratorOperations{R,G1,T,P}
    variablegens::VariableGeneratorOperations{R,G2,T,P}
    storages::StorageOperations{R,G3,T,P}
    transmission::TransmissionOperations{R,I,T,P}
end

function loadoperations(
    techs::Technologies,
    regions::Dict{String,Int}, periods::Dict{String,Int}, T::Int,
    resourcepath::String
)

    R = length(regions)
    P = length(periods)

    thermal = ThermalGeneratorOperations{R,T,P}(
        techs.thermal, joinpath(resourcepath, "thermal"))

    variable = VariableGeneratorOperations{R,T,P}(
        techs.variable, regions, periods,
        joinpath(resourcepath, "variable"))

    storages = StorageOperations{R,T,P}(
        techs.storage, joinpath(resourcepath, "storage"))

    transmission = TransmissionOperations{T,P}(
        techs.interface, joinpath(resourcepath, "transmission"))

    return Operations(thermal, variable, storages, transmission)

end

welfare(x::Operations) =
    welfare(x.thermalgens) + welfare(x.variablegens) + welfare(x.storages)

ucap(x::Operations) =
    sum(x.thermalgens.ucap) + sum(x.variablegens.ucap) + sum(x.storages.ucap)

energy(x::Operations, r::Int, t::Int, p::Int) =
    x.thermalgens.totalenergy[r,t,p] +
    x.variablegens.totalenergy[r,t,p] +
    x.storages.totalenergy[r,t,p]

raisereserve(x::Operations, r::Int, t::Int, p::Int) =
    x.thermalgens.totalraisereserve[r,t,p] +
    x.variablegens.totalraisereserve[r,t,p] +
    x.storages.totalraisereserve[r,t,p]

lowerreserve(x::Operations, r::Int, t::Int, p::Int) =
    x.thermalgens.totallowerreserve[r,t,p] +
    x.variablegens.totallowerreserve[r,t,p] +
    x.storages.totallowerreserve[r,t,p]
