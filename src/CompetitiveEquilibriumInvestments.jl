module CompetitiveEquilibriumInvestments

using JuMP

import MathOptInterface
const MOI = MathOptInterface

const ExpressionRef = GenericAffExpr{Float64,VariableRef}
const QuadExpressionRef = GenericQuadExpr{Float64,VariableRef}

const ConstrRef{T} = ConstraintRef{Model,MOI.ConstraintIndex{
     MOI.ScalarAffineFunction{Float64},T},ScalarShape}

const LessThanConstraintRef    = ConstrRef{MOI.LessThan{Float64}}
const GreaterThanConstraintRef = ConstrRef{MOI.GreaterThan{Float64}}
const EqualToConstraintRef     = ConstrRef{MOI.EqualTo{Float64}}

const SparseAxisArray{T,N} = JuMP.Containers.SparseAxisArray{T,N,NTuple{N,Int64}}

abstract type AbstractProblem{R,G1,G2,G3,T,P} end
abstract type AbstractScenario end

include("resources.jl")
include("investments.jl")
include("operations/operations.jl")
include("markets/markets.jl")
include("Scenario.jl")
include("InvestmentProblem.jl")

export
    Technologies, ThermalGenerators, VariableGenerators, StorageDevices,
    InitialConditions, InitialInvestments,
    Investments, ResourceInvestments,
    Operations, ThermalGeneratorOperations, VariableGeneratorOperations,
                StorageOperations, TransmissionOperations,
    Markets, CapacityMarket, EnergyMarket,
             RaiseReserveMarket, LowerReserveMarket,
    Scenario, InvestmentProblem, solve!

end
