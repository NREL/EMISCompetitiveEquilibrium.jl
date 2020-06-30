struct ResourceInvestments{R,G}

    # Parameters

    optioncost::Vector{Float64}     # one-time ($/unit, g)
    buildcost::Vector{Float64}      # one-time
    recurringcost::Vector{Float64}  # recurring

    optionleadtime::Vector{Int}     # investment periods, g
    buildleadtime::Vector{Int}
    capitalamortizationtime::Vector{Int}

    maxnewoptions::Matrix{Int} # investment periods, r x g
    maxnewbuilds::Matrix{Int}

    # Variables

    newoptions::Matrix{VariableRef} # New options purchased (r x g)
    newbuilds::Matrix{VariableRef}  # New options exercised / construction starts

    # Expressions

    vesting::Matrix{ExpressionRef} # Options vesting (r x g)
    buildable::Matrix{ExpressionRef} # Units buildable (option vested)
    holding::Matrix{ExpressionRef} # Units holding (buildable but not building)
    building::Matrix{ExpressionRef} # Units under construction

    dispatchable::Matrix{ExpressionRef} # Units dispatchable (r x g)
    ucap::Matrix{ExpressionRef} # Unforced dispatchable capacity (MW, r x g)

    investmentcosts::Matrix{ExpressionRef} # $, r x g

    # Constraints
    minnewoptions::Matrix{GreaterThanConstraintRef} # r x g
    maxnewoptions::Matrix{LessThanConstraintRef}
    minnewbuilds::Matrix{GreaterThanConstraintRef}
    maxnewbuilds_optionlimit::Matrix{LessThanConstraintRef}
    maxnewbuilds_physicallimit::Matrix{LessThanConstraintRef}

    function ResourceInvestments{}(
        optioncost, buildcost, recurringcost,
        optionleadtime, buildleadtime, capitalamortizationtime,
        maxnewoptions, maxnewbuilds)

        R, G = size(maxnewoptions)

        @assert length(optioncost) == G
        @assert length(buildcost) == G
        @assert length(recurringcost) == G

        @assert length(optionleadtime) == G
        @assert length(buildleadtime) == G
        @assert length(capitalamortizationtime) == G

        @assert size(maxnewbuilds) == (R,G)

        new{R,G}(

            optioncost, buildcost, recurringcost,
            optionleadtime, buildleadtime, capitalamortizationtime,
            maxnewoptions, maxnewbuilds,

            Matrix{VariableRef}(undef,R,G),
            Matrix{VariableRef}(undef,R,G),

            Matrix{ExpressionRef}(undef,R,G),
            Matrix{ExpressionRef}(undef,R,G),
            Matrix{ExpressionRef}(undef,R,G),
            Matrix{ExpressionRef}(undef,R,G),

            Matrix{ExpressionRef}(undef,R,G),
            Matrix{ExpressionRef}(undef,R,G),

            Matrix{ExpressionRef}(undef,R,G),

            Matrix{GreaterThanConstraintRef}(undef,R,G},
            Matrix{LessThanConstraintRef}(undef,R,G},
            Matrix{GreaterThanConstraintRef}(undef,R,G},
            Matrix{LessThanConstraintRef}(undef,R,G},
            Matrix{LessThanConstraintRef}(undef,R,G}

        )

    end

end

function setup!(
    invs::ResourceInvestments{R,G},
    m::Model, existingunits::Matrix{Int})

    # Variables
    invs.newoptions .= @variable(m, [1:R, 1:G], Int)
    invs.newbuilds .= @variable(m, [1:R, 1:G], Int)

    # Expressions
    # TODO

    # Constraints
    # TODO

    return

end

function setup!(
    invs::ResourceInvestments{R,G},
    m::Model,
    parentinvs::ResourceInvestments{R,G}
)
    error("Not yet implemented")
end

welfare(x::ResourceInvestments) = -sum(x.investmentcosts)


struct Investments{R,G1,G2,G3}
    thermalgens::ResourceInvestments{R,G1}
    variablegens::ResourceInvestments{R,G2}
    storages::ResourceInvestments{R,G3}
end

welfare(x::Investments) =
    welfare(x.thermalgens) + welfare(x.variablegens) + welfare(x.storages)
