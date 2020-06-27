# R: number of regions
# G: number of generators (either thermal / VG / storage)
# T: number of operations timesteps per period
# P: number of operations periods

struct InvestmentProblem{R,G,T,P}

    model::Model

    thermaltechs::ThermalGenerators
    variabletechs::VariableGenerators
    storagetechs::StorageDevices

    initialconditions::InitialConditions
    rootscenario::Scenario{R,G,T,P}

end

struct InitialConditions{R,G}
    existingunits::Matrix{Int} # Number of existing units (r x g)
end

struct Scenario{R,G,T,P}

    thermalgens_investments::ResourceInvestments{R,G}
    variablegens_investments::ResourceInvestments{R,G}
    storages_investments::ResourceInvestments{R,G}

    thermalgens_operations::ThermalGeneratorsOperations{R,G,T,P}
    variablegens_operations::VariableGeneratorsOperations{R,G,T,P}
    storages_operations::StorageDevicesOperations{R,G,T,P}

    capacity_market::CapacityMarket
    energy_market::EnergyMarket{R,T,P}
    raisereserve_market::RaiseReserveMarket{R,T,P}
    lowerreserve_market::LowerReserveMarket{R,T,P}

    probability::Float64
    previnvestmentperiod::Union{Scenario{R,G,T,P},Nothing}
    nextinvestmentperiods::Vector{Scenario{R,G,T,P}}

end

welfare(s::Scenario) = sum(welfare.(getproperty.(s,
    [:thermalgens_investments, :variablegens_investments, :storages_investments,
     :thermalgens_operations,  :variablegens_operations,  :storages_operations,
     :capacity_market, :energy_market, :raisereserve_market, :lowerreserve_market,
    ]
