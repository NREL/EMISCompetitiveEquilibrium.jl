include("thermal.jl")
include("variable.jl")
include("storage.jl")
include("transmission.jl")

struct Operations{R,G1,G2,G3,I,T,P}
    thermal::ThermalGeneratorOperations{R,G1,T,P}
    variable::VariableGeneratorOperations{R,G2,T,P}
    storage::StorageOperations{R,G3,T,P}
    transmission::TransmissionOperations{R,I,T,P}
end

function loadoperations(
    techs::Technologies,
    regions::Dict{String,Int}, periods::Dict{String,Int}, T::Int,
    resourcepath::String
)

    R = length(regions)
    P = length(periods)

    thermal = ThermalGeneratorOperations{T,P}(
        techs.thermal, regions, joinpath(resourcepath, "thermal"))

    variable = VariableGeneratorOperations{T}(
        techs.variable, regions, periods,
        joinpath(resourcepath, "variable"))

    storages = StorageOperations{T,P}(
        techs.storage, regions, joinpath(resourcepath, "storage"))

    transmission = TransmissionOperations{T,P}(
        techs.interface, joinpath(resourcepath, "transmission"))

    return Operations(thermal, variable, storages, transmission)

end

welfare(x::Operations) =
    welfare(x.thermal) + welfare(x.variable) + welfare(x.storage)

ucap(x::Operations) =
    sum(x.thermal.ucap) + sum(x.variable.ucap) + sum(x.storage.ucap)

energy(x::Operations, r::Int, t::Int, p::Int) =
    x.thermal.totalenergy[r,t,p] +
    x.variable.totalenergy[r,t,p] +
    x.storage.totalenergy[r,t,p]

raisereserve(x::Operations, r::Int, t::Int, p::Int) =
    x.thermal.totalraisereserve[r,t,p] +
    x.variable.totalraisereserve[r,t,p] +
    x.storage.totalraisereserve[r,t,p]

lowerreserve(x::Operations, r::Int, t::Int, p::Int) =
    x.thermal.totallowerreserve[r,t,p] +
    x.variable.totallowerreserve[r,t,p] +
    x.storage.totallowerreserve[r,t,p]
