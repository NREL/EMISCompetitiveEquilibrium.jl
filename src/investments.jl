struct InitialInvestments{R,G}
    options::Matrix{Int} # Existing (buildable) options (r x g)
    builds::Matrix{Int}  # Existing (dispatchable) units
end

struct ResourceInvestments{R,G}

    # Parameters

    # Capital costs are considered sunk and so modeled as one-time expenses,
    # although in terms of cash flow they may actually be amortized over time
    optioncost::Vector{Float64}     # ($/unit, g)
    buildcost::Vector{Float64}

    optionleadtime::Vector{Int}     # investment periods, g
    buildleadtime::Vector{Int}

    newoptionslimit::Matrix{Int} # investment periods, r x g
    newbuildslimit::Matrix{Int}

    # Variables

    newoptions::Matrix{VariableRef} # New options purchased (r x g)
    newbuilds::Matrix{VariableRef}  # New options exercised / construction starts

    # Expressions

    vesting::Matrix{ExpressionRef} # Options vesting (r x g)
    buildable::Matrix{ExpressionRef} # Units buildable (option vested but not used)
    building::Matrix{ExpressionRef} # Units under construction (option used)
    dispatchable::Matrix{ExpressionRef} # Units dispatchable (finished construction)
    retired::Matrix{ExpressionRef} # Units retired

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
    m::Model,
    history::Union{InitialInvestments{R,G},ResourceInvestments{R,G}})

    # Variables

    invs.newoptions .= @variable(m, [1:R, 1:G], Int)
    invs.newbuilds .= @variable(m, [1:R, 1:G], Int)
    invs.newretirements .= @variable(m, [1:R, 1:G], Int)

    # Expressions

    invs.optionsvested .=
        @expression(m, [r in regions, g in gens],
                    maturing(s, r, g, :optionleadtime, :newoptions)

    invs.buildsfinished .= _
        @expression(m, [r in regions, g in gens],
                    maturing(s, r, g, :buildleadtime, :newbuilds)

    setup_unitstates!(invs, m, history)

    invs.investmentcosts .=
        @expression(m, [r in regions, g in gens],
                    invs.optioncost[r,g] * invs.newoptions[r,g] +
                    invs.buildcost[r,g] * invs.newbuilds[r,g] +
                    invs.retirementcost[r,g] * invs.newretirements[r,g])

    # Constraints

    invs.minnewoptions .=
        @constraint(m, [r in regions, g in gens],
                    invs.newoptions[r,g] >= 0)

    invs.maxnewoptions .=
        @constraint(m, [r in regions, g in gens],
                    invs.newoptions[r,g] <= invs.newoptionslimit[r,g])

    invs.minnewbuilds .=
        @constraint(m, [r in regions, g in gens],
                    invs.newbuilds[r,g] >= 0)

    invs.maxnewbuilds_optionlimit .=
        @constraint(m, [r in regions, g in gens],
                    invs.newbuilds[r,g] <= invs.buildable[r,g])

    invs.maxnewbuilds_physicallimit .=
        @constraint(m, [r in regions, g in gens],
                    invs.newbuilds[r,g] <= invs.newbuildslimit[r,g])

    return

end

function setup_unitstates!(
    invs::ResourceInvestments{R,G},
    m::Model,
    existing::InitialInvestments{R,G}
)

    invs.vesting .=
        @expression(m, [r in regions, g in gens],
                    0 + invs.newoptions[r,g]
                    - invs.optionsvested[r,g])

    invs.buildable .=
        @expression(m, [r in regions, g in gens],
                    existing.options[r,g] + invs.optionsvested[r,g]
                    - invs.newbuilds[r,g])

    invs.building .=
        @expression(m, [r in regions, g in gens],
                    0 + invs.newbuilds[r,g]
                    - invs.buildsfinished[r,g])

    invs.dispatchable .=
        @expression(m, [r in regions, g in gens],
                    existing.builds[r,g] + invs.buildsfinished[r,g]
                    - invs.retirements[r,g])

    invs.retired .=
        @expression(m, [r in regions, g in gens],
                    0 + invs.retirements[r,g])

end

function setup_unitstates!(
    invs::ResourceInvestments{R,G},
    m::Model,
    parentinvs::ResourceInvestments{R,G}
)

    invs.vesting .=
        @expression(m, [r in regions, g in gens],
                    parentinvs.vesting[r,g] + invs.newoptions[r,g]
                    - invs.optionsvested[r,g])

    invs.buildable .=
        @expression(m, [r in regions, g in gens],
                    parentinvs.buildable[r,g] + invs.optionsvested[r,g]
                    - invs.newbuilds[r,g])

    invs.building .=
        @expression(m, [r in regions, g in gens],
                    parentinvs.building + invs.newbuilds[r,g]
                    - invs.buildsfinished[r,g])

    invs.dispatchable .=
        @expression(m, [r in regions, g in gens],
                    parentinvs.dispatchable[r,g] + invs.buildsfinished[r,g]
                    - invs.retirements[r,g])

    invs.retired .=
        @expression(m, [r in regions, g in gens],
                    parentinvs.retired[r,g] + invs.retirements[r,g])


end

welfare(x::ResourceInvestments) = -sum(x.investmentcosts)


struct Investments{R,G1,G2,G3}
    thermalgens::ResourceInvestments{R,G1}
    variablegens::ResourceInvestments{R,G2}
    storages::ResourceInvestments{R,G3}
end

welfare(x::Investments) =
    welfare(x.thermalgens) + welfare(x.variablegens) + welfare(x.storages)
