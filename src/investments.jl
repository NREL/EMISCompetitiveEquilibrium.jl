struct ResourceInvestments{R,G}

    # Parameters

    optioncost::Vector{Float64}     # one-time ($/unit, g)
    buildcost::Vector{Float64}      # one-time
    recurringcost::Vector{Float64}  # recurring

    optionleadtime::Vector{Int}     # (investment periods, g)
    buildleadtime::Vector{Int}
    capitalamortizationtime::Vector{Int}

    maxnewoptions::Matrix{Int} # (investment periods, r x g)
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

    # Constraints:
    # Min/max new options
    # Min/max new builds

end

welfare(x::ResourceInvestments) = -sum(x.investmentcosts)
