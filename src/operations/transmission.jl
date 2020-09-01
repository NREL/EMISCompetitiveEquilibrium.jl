mutable struct TransmissionOperations{R,I,T,P}

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
        limits::Vector{Float64}
    ) where {R,T,P}

        I = length(limits)
        @assert all(x -> x >= 0, limits)

        new{R,I,T,P}(limits)

    end

end

function TransmissionOperations{T,P}(
    interfaces::Interfaces{I,R}, transmissionpath::String
) where {I,R,T,P}

    transmissiondata =
        DataFrame!(CSV.File(joinpath(transmissionpath, "parameters.csv")))

    interfacelookup = Dict(zip(interfaces.name, 1:I))
    limits = zeros(Float64, I)

    for row in eachrow(transmissiondata)
        int_idx = interfacelookup[row.interface]
        limits[int_idx] = row.limit
    end

    return TransmissionOperations{R,T,P}(limits)

end

function setup!(
    tx::TransmissionOperations{R,I,T,P},
    interfaces::Interfaces{I,R},
    m::Model
) where {R,I,T,P}

    # Variables

    tx.flows =
        @variable(m, [i in 1:I, t in 1:T, p in 1:P])

    # Expressions

    tx.exports =
        @expression(m, [r in 1:R, t in 1:T, p in 1:P],
                    sum(flowout(r, l, tx.flows[i,t,p])
                        for (i, l) in enumerate(interfaces.regions)))

    # Constraints

    tx.maxflow_forward =
        @constraint(m, [i in 1:I, t in 1:T, p in 1:P],
                    tx.flows[i,t,p] <= tx.limits[i])

    tx.maxflow_back =
        @constraint(m, [i in 1:I, t in 1:T, p in 1:P],
                    -tx.limits[i] <= tx.flows[i,t,p])

end

flowout(r::Int, label::Tuple{Int,Int}, x) =
    if r == first(label)
        x
    elseif r == last(label)
        -x
    else
        zero(x)
    end
