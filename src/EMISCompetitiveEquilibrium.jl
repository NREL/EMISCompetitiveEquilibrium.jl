module CompetitiveEquilibriumInvestments

using JuMP

import MathOptInterface
const MOI = MathOptInterface

import DataFrames: DataFrame, DataFrame!, stack, Not
import CSV

const ExpressionRef = GenericAffExpr{Float64,VariableRef}
const QuadExpressionRef = GenericQuadExpr{Float64,VariableRef}

const ConstrRef{T} = ConstraintRef{Model,MOI.ConstraintIndex{
     MOI.ScalarAffineFunction{Float64},T},ScalarShape}

const LessThanConstraintRef    = ConstrRef{MOI.LessThan{Float64}}
const GreaterThanConstraintRef = ConstrRef{MOI.GreaterThan{Float64}}
const EqualToConstraintRef     = ConstrRef{MOI.EqualTo{Float64}}

const SparseAxisArray{T,N} = JuMP.Containers.SparseAxisArray{T,N,NTuple{N,Int64}}
const Optimizer = Union{Type{<:MOI.AbstractOptimizer}, MOI.OptimizerWithAttributes}

abstract type AbstractProblem{R,G1,G2,G3,I,T,P} end
abstract type AbstractScenario end

function varnames!(vars::Array{VariableRef},
                   basename::String, labels::Vector{String}...)

    dims = size(vars)
    dims == length.(labels) || error("Provided labels do not match array size")

    for idxs in Iterators.product(Base.OneTo.(dims)...)
        idx_labels = getindex.(labels, idxs)
        set_name(vars[idxs...], basename * "[" * join(idx_labels, ",") * "]")
    end

end

include("readutils.jl")

include("resources.jl")
include("investments.jl")
include("operations/operations.jl")
include("markets/markets.jl")
include("Scenario.jl")
include("InvestmentProblem.jl")
include("report.jl")

export

    Technologies,
    ThermalGenerators, VariableGenerators, StorageDevices, Interfaces,

    InitialConditions, InitialInvestments, Investments, ResourceInvestments,

    Operations,
    ThermalGeneratorOperations, VariableGeneratorOperations,
    StorageOperations, TransmissionOperations,

    Markets, CapacityMarket, RECMarket,
    EnergyMarket, RaiseReserveMarket, LowerReserveMarket,

    Scenario, InvestmentProblem, solve!, report

end
