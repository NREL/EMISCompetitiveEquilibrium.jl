module CompetitiveEquilibriumInvestments

using JuMP

ExpressionRef = GenericAffineExpr{Float64,VariableRef}

include("resources.jl")
include("ScenarioTree.jl")


end
