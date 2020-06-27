struct ThermalGenerators

    name::Vector{String}             # g
    owner::Vector{String}            # g

    mingen::Vector{Float64}          # (MW/unit, g)
    maxgen::Vector{Float64}          # (MW/unit, g)

    minuptime::Vector{Int}           # (hours, g)
    mindowntime::Vector{Int}         # (hours, g)
    maxrampup::Vector{Float64}       # (MW/unit/hour, g)
    maxrampdown::Vector{Float64}     # (MW/unit/hour, g)
    capacitycredit::Vector{Float64}  # (fraction, g)

end

struct VariableGenerators

    name::Vector{String}    # g
    owner::Vector{String}   # g
    maxgen::Vector{Float64} # (MW/unit, g)

end

struct Storages

    name::Vector{String}  # g
    owner::Vector{String} # g

    maxcharge::Vector{Float64}    # (MW, g)
    maxdischarge::Vector{Float64} # (MW, g)
    maxenergy::Vector{Float64}    # (MWh, g)

    chargeefficiency::Vector{Float64}    # (fraction, g)
    dischargeefficiency::Vector{Float64} # (fraction, g)
    carryoverefficieny::Vector{Float64}  # (fraction, g)

end
