module CompetitiveEquilibriumInvestments

using JuMP

import MathOptInterface
const MOI = MathOptInterface

const ExpressionRef = GenericAffineExpr{Float64,VariableRef}

const ConstraintRef{T} = Array{ConstraintRef{Model,MOI.ConstraintIndex{
     MOI.ScalarAffineFunction{Float64},T},ScalarShape},2}

const LessThanConstraintRef    = ConstraintRef{MOI.LessThan{Float64}}
const GreaterThanConstraintRef = ConstraintRef{MOI.GreaterThan{Float64}}
const EqualToConstraintRef     = ConstraintRef{MOI.EqualTo{Float64}}

include("resources.jl")
include("investments.jl")
include("operations/operations.jl")
include("markets/markets.jl")
include("Scenario.jl")
include("InvestmentProblem.jl")

end
