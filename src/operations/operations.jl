include("thermal.jl")
include("variable.jl")
include("storage.jl")

struct Operations{R,G1,G2,G3,T,P}
    thermalgens::ThermalGeneratorOperations{R,G1,T,P}
    variablegens::VariableGeneratorOperations{R,G2,T,P}
    storages::StorageOperations{R,G3,T,P}
end

welfare(x::Operations) =
    welfare(x.thermalgens) + welfare(x.variablegens) + welfare(x.storages)

ucap(x::Operations) =
    sum(x.thermalgens.ucap) + sum(x.variablegens.ucap) + sum(x.storages.ucap)
