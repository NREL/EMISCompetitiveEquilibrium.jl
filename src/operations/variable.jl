struct VariableGeneratorsOperations{R,G,T,P}

    # Parameters

    fixedcost::Vector{Float64}      # $/unit/investment period, g
    variablecost::Vector{Float64}   # $/MW/hour, g
    capacityfactor::Matrix{Float64} # fraction, g

    # Variables

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    operatingcosts::Matrix{ExpressionRef} # Operating costs ($, r x g)

    # Constraints

    mingeneration::Array{<:ConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{<:ConstraintRef,4}
    minlowerreserve::Array{<:ConstraintRef,4}
    maxlowerreserve::Array{<:ConstraintRef,4}
    minraisereserve::Array{<:ConstraintRef,4}
    maxraisereserve::Array{<:ConstraintRef,4}

    maxrampdown::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)
    maxrampup::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)

end

function setup!(
    ops::VariableGeneratorOperations{R,G1,G2}, m::Model,
    invs::ResourceInvestments{R,G2})
    error("Not yet implemented")
end

welfare(x::VariableGenerationOperations) = -sum(x.operatingcosts)
