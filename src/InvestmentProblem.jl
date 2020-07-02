# R: number of regions
# G: number of generators (either thermal / VG / storage)
# T: number of operations timesteps per period
# P: number of operations periods

mutable struct InvestmentProblem{R,G1,G2,G3,T,P}

    model::Model

    thermaltechs::ThermalGenerators{G1}
    variabletechs::VariableGenerators{G2}
    storagetechs::StorageDevices{G3}

    thermalstart::InitialInvestments{R,G1}
    variablestart::InitialInvestments{R,G2}
    storagestart::InitialInvestments{R,G3}

    discountrate::Float64

    rootscenario::Scenario{R,G1,G2,G3,T,P}

    InvestmentProblem{T,P}(
        model::Model,
        thermaltechs::ThermalGenerators{G1},
        variabletechs::VariableGenerators{G2},
        storagetechs::StorageDevices{G3},
        thermalstart::InitialInvestments{R,G1},
        variablestart::InitialInvestments{R,G2},
        storagestart::InitialInvestments{R,G3},
        discountrate::Float64
    ) = new{R,G1,G2,G3,T,P}(
        model, thermaltechs, variabletechs, storagetechs,
        initialconditions, discountrate)
end

function InvestmentProblem(
    thermaltechs::ThermalGenerators{G1},
    variabletechs::VariableGenerators{G2},
    storagetechs::StorageDevices{G3},
    thermalstart::InitialInvestments{R,G1},
    variablestart::InitialInvestments{R,G2},
    storagestart::InitialInvestments{R,G3},
    discountrate::Float64,
    investments::Investments{R,G1,G2,G3}
    operations::Operations{R,G1,G2,G3,T,P}
    markets::Markets{R,T,P}
) where {R,G1,G2,G3,T,P}

    invprob = InvestmentProblem{T,P}(
        Model(), thermaltechs, variabletechs, storagetechs,
        initialconds, discountrate)

    root = Scenario(invprob, investments, operations, markets)
    invprob.rootscenario = root

    return invprob

end

function solve!(invprob::InvestmentProblem)
    @objective(invprob.m, Max, welfare(invprob.rootscenario))
    optimize!(invprob.model)
    return
end
