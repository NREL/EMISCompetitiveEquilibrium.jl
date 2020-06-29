struct Operations{R,G1,G2,G3,T,P}
    thermalgens::ThermalGeneratorOperations{R,G1,T,P}
    variablegens::VariableGeneratorOperations{R,G2,T,P}
    storages::StorageOperations{R,G3,T,P}
end

welfare(x::Operations) =
    welfare(x.thermalgens) + welfare(x.variablegens) + welfare(x.storages)

function setupoperations!(s::Scenario)
    # Wire up variables, expressions, and constraints
end

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

    maxrampdown::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)
    maxrampup::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)

end

welfare(x::ThermalGeneratorOperations) = -sum(x.operatingcosts)


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

welfare(x::VariableGenerationOperations) = -sum(x.operatingcosts)


struct StoragesOperations{R,G,T,P}

    # Variables

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Expressions

    stateofcharge::Array{VariableRef,4}  # MWh, r x g x t x p

    # Constraints

    mingeneration::Array{<:ConstraintRef,4} # (r x g x t x p)
    maxgeneration::Array{<:ConstraintRef,4}
    mingeneration_soc::Array{<:ConstraintRef,4}
    maxgeneration_soc::Array{<:ConstraintRef,4}

    minlowerreserve::Array{<:ConstraintRef,4}
    maxlowerreserve::Array{<:ConstraintRef,4}
    minraisereserve::Array{<:ConstraintRef,4}
    maxraisereserve::Array{<:ConstraintRef,4}

    maxrampdown::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)
    maxrampup::Array{<:ConstraintRef,4}   # (r x g x t-1 x p)

end

welfare(::StorageOperations) = 0.
