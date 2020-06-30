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

function setup!(
    ops::StorageOperations{R,G1,G2,G3}, m::Model,
    invs::ResourceInvestments{R,G3}) where {R,G1,G2,G3}
    error("Not yet implemented")
end

welfare(::StorageOperations) = 0.
