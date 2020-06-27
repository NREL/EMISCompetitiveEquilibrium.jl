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
    # Min/max unit commitment
    # Min/max startup/shutdown
    # Unit commitment continuity
    # Min up/down time
    # Ramping constraints
    # Energy-reserve interactions

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
    # Energy-reserve interactions

end

welfare(x::VariableGenerationOperations) = -sum(x.operatingcosts)


struct StoragesOperations{R,G,T,P}

    # Variables

    energydispatch::Array{VariableRef,4} # Energy dispatch (MW, r x g x t x p)
    raisereserve::Array{VariableRef,4}   # Raise reserves provisioned
    lowerreserve::Array{VariableRef,4}   # Lower reserves provisioned

    # Constraints
    # Energy-reserve interactions
    # State-of-charge

end

welfare(::StorageOperations) = 0.
