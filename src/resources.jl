abstract type AbstractTechnology{G} end

struct ThermalGenerators{G1} <: AbstractTechnology{G1}

    name::Vector{String}             # g
    owner::Vector{String}            # g

    mingen::Vector{Float64}          # (MW/unit, g)
    maxgen::Vector{Float64}          # (MW/unit, g)

    minuptime::Vector{Int}           # (hours, g)
    mindowntime::Vector{Int}         # (hours, g)
    maxrampup::Vector{Float64}       # (MW/unit/hour, g)
    maxrampdown::Vector{Float64}     # (MW/unit/hour, g)

    capacitycredit::Vector{Float64}  # (fraction, g)

    function ThermalGenerators{}(args...)
        G = length(first(args))
        @assert all(a -> length(a) == G, args)
        new{G}(args...)
    end

end

struct VariableGenerators{G2} <: AbstractTechnology{G2}

    name::Vector{String}    # g
    owner::Vector{String}   # g

    maxgen::Vector{Float64} # (MW/unit, g)

    function VariableGenerators{}(args...)
        G = length(first(args))
        @assert all(a -> length(a) == G, args)
        new{G}(args...)
    end

end

struct StorageDevices{G3} <: AbstractTechnology{G3}

    name::Vector{String}  # g
    owner::Vector{String} # g

    maxcharge::Vector{Float64}    # (MW, g)
    maxdischarge::Vector{Float64} # (MW, g)
    maxenergy::Vector{Float64}    # (MWh, g)

    chargeefficiency::Vector{Float64}    # (fraction, g)
    dischargeefficiency::Vector{Float64} # (fraction, g)
    carryoverefficiency::Vector{Float64}  # (fraction, g)

    capacitycredit::Vector{Float64}  # (fraction, g)

    function StorageDevices{}(args...)
        G = length(first(args))
        @assert all(a -> length(a) == G, args)
        new{G}(args...)
    end

end

struct Interfaces{I,R} <: AbstractTechnology{I}

    name::Vector{String}
    regions::Vector{Tuple{Int,Int}}

    function Interfaces{R}(
        name::Vector{String},
        regions::Vector{Tuple{Int,Int}}
    ) where R

        I = length(name)
        @assert I == length(regions)

        @assert all(x -> 1 <= first(x) <= R, regions)
        @assert all(x -> 1 <= last(x) <= R, regions)
        @assert allunique(tuple.(minimum.(regions), maximum.(regions)))

        new{I,R}(name, regions)

    end

end

struct Technologies{G1,G2,G3,I,R}

    thermal::ThermalGenerators{G1}
    variable::VariableGenerators{G2}
    storage::StorageDevices{G3}
    interface::Interfaces{I,R}

    function Technologies{}(
        thermal::ThermalGenerators{G1},
        variable::VariableGenerators{G2},
        storage::StorageDevices{G3},
        interface::Interfaces{I,R}
    ) where {G1,G2,G3,I,R}

        allunique(vcat(thermal.name, variable.name,
                       storage.name, interface.name)) ||
            error("Resource class names must be unique")

        new{G1,G2,G3,I,R}(thermal, variable, storage, interface)

    end

end
