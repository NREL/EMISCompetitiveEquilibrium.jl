mutable struct TransmissionOperations{R,T,P}

    labels::Vector{Pair{Int,Int}}

    # Parameters

    limits::Vector{Float64}

    # Variables

    flows::Array{VariableRef,3} # (i x t x p)

    # Expressions

    exports::Array{ExpressionRef,3} # (r x t x p)

    # Constraints

    maxflow_forward::Array{LessThanConstraintRef,3} # (i x t x p)
    maxflow_back::Array{LessThanConstraintRef,3}

    function TransmissionOperations{R,T,P}(
        labels::Vector{Pair{Int,Int}},
        limits::Vector{Float64}
    ) where {R,T,P}

        I = length(labels)
        @assert length(limits) == I

        @assert all(x -> 1 <= first(x) <= R, labels)
        @assert all(x -> 1 <= last(x) <= R, labels)
        @assert allunique(tuple.(minimum.(labels), maximum.(labels)))

        @assert all(x -> x >= 0, limits)

        new{R,T,P}(labels, limits)

    end

end

function setup!(
    tx::TransmissionOperations{R,T,P},
    m::Model
) where {R,T,P}

    interfaces = 1:length(tx.labels)
    regions = 1:R
    timesteps = 1:T
    periods = 1:P

    # Variables

    tx.flows =
        @variable(m, [i in interfaces, t in timesteps, p in periods])

    # Expressions

    tx.exports =
        @expression(m, [r in regions, t in timesteps, p in periods],
                    sum(flowout(r, l, tx.flows[i,t,p])
                        for (i, l) in enumerate(tx.labels)))

    # Constraints

    tx.maxflow_forward =
        @constraint(m, [i in interfaces, t in timesteps, p in periods],
                    tx.flows[i,t,p] <= tx.limits[i])

    tx.maxflow_back =
        @constraint(m, [i in interfaces, t in timesteps, p in periods],
                    -tx.limits[i] <= tx.flows[i,t,p])

end

flowout(r::Int, label::Pair{Int,Int}, x) =
    if r == first(label)
        x
    elseif r == last(label)
        -x
    else
        zero(x)
    end
