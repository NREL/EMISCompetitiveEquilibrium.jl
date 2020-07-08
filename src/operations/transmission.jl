struct TransmissionOperations{R,T,P}

    labels::Vector{Tuple{Int,Int}}

    # Parameters

    limits::Vector{Float64}

    # Variables

    flows::Array{VariableRef,3} # (i x t x p)

    # Constraints

    maxflow_forward::Array{<:ConstraintRef,3} # (i x t x p)
    maxflow_back::Array{<:ConstraintRef,3}

end

function flow(tx::TransmissionOperations, from::Int, to::Int)

    # TODO: Find to, from regions in tx.labels if they exist
    # Negate to reserve flow direction if needed
    # If regions not in labels, return zero-expression

    # Alternatively, could define net import function that tracks
    # net power transfer into a given node number (seems more useful?)

end

function setup!(
    tx::TransmissionOperations{R,T,P}
    m::Model, periodweights::Vector{Float64})

    # Variables

    # Expressions

    # Constraints

end
