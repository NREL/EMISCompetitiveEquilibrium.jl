struct ThermalGeneratorOperations{R,G,T,P}

    # Parameters

    fixedcost::Vector{Float64}    # $/unit/investment period, g
    variablecost::Vector{Float64} # $/MW/hour, g
    startupcost::Float64          # $/startup/unit, g
    shutdowncost::Float64         # $/shutdown/unit, g

    # Variables

    committed::Array{VariableRef,4} # Units committed (r x g x t x p)
    started::Array{VariableRef,4}   # Units started up
    shutdown::Array{VariableRef,4}  # Units shut down

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    operatingcosts::Matrix{ExpressionRef} # Operating costs ($, r x g)

    # Constraints

    minunitcommitment::Array{<:ConstraintRef,4} # (r x g x t x p)
    maxunitcommitment::Array{<:ConstraintRef,4}
    minunitstartups::Array{<:ConstraintRef,4}
    maxunitstartups::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)
    minunitshutdowns::Array{<:ConstraintRef,4}  # (r x g x t x p)
    maxunitshutdowns::Array{<:ConstraintRef,4}  # (r x g x t-1 x p)

    unitcommitmentcontinuity::Array{<:ConstraintRef,4}  # (r x g x t-1 x p)
    minunituptime::Array{<:ConstraintRef,4} # (r x g x t-? x p)
    minunitdowntime::Array{<:ConstraintRef,4}

    mingeneration::Array{<:ConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{<:ConstraintRef,4}
    minlowerreserve::Array{<:ConstraintRef,4}
    maxlowerreserve::Array{<:ConstraintRef,4}
    minraisereserve::Array{<:ConstraintRef,4}
    maxraisereserve::Array{<:ConstraintRef,4}

    maxrampdown::Array{<:ConstraintRef,4} # (r x g x t-1 x p)
    maxrampup::Array{<:ConstraintRef,4}

end

function setup!(
    ops::ThermalGeneratorOperations{R,G}, m::Model,
    invs::ResourceInvestments{R,G})
    error("Not yet implemented")
end

welfare(x::ThermalGeneratorOperations) = -sum(x.operatingcosts)
