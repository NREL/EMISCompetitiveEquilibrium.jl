include("capacity.jl")
include("rec.jl")
include("energy.jl")
include("raisereserve.jl")
include("lowerreserve.jl")

struct Markets{R,T,P}
   capacity::CapacityMarket
   rec::RECMarket
   energy::EnergyMarket{R,T,P}
   raisereserve::RaiseReserveMarket{R,T,P}
   lowerreserve::LowerReserveMarket{R,T,P}
end

function loadmarkets(
    regions::Dict{String,Int}, periods::Dict{String,Int}, n_timesteps::Int,
    resourcepath::String
)
    capacity = CapacityMarket(joinpath(resourcepath, "capacity"))

    rec = RECMarket(joinpath(resourcepath, "rec"))

    energy = loadmarket(
        EnergyMarket, regions, periods, n_timesteps,
        joinpath(resourcepath, "energy"))

    raisereserve = loadmarket(
        RaiseReserveMarket, regions, periods, n_timesteps,
        joinpath(resourcepath, "raisereserve"))

    lowerreserve = loadmarket(
        LowerReserveMarket, regions, periods, n_timesteps,
        joinpath(resourcepath, "lowerreserve"))

    return Markets(capacity, rec, energy, raisereserve, lowerreserve)

end

function loadmarket(
    market::Type, regions::Dict{String,Int}, periods::Dict{String,Int}, T::Int,
    marketpath::String
)

    R = length(regions)
    P = length(periods)

    rulesdata = DataFrame!(CSV.File(joinpath(marketpath, "rules.csv"),
                                    types=scenarios_market_param_types))
    demanddata = DataFrame!(CSV.File(joinpath(marketpath, "demand.csv")))
    demanddata = stack(demanddata, Not([:period, :timestep]),
                       variable_name=:region, value_name=:demand)

    pricecap = zeros(Float64, R)
    demand = zeros(Float64, R, T, P)

    for row in eachrow(rulesdata)
        r_idx = regions[row.region]
        pricecap[r_idx] = row.pricecap
    end

    for row in eachrow(demanddata)
        r_idx = regions[row.region]
        t = row.timestep
        p_idx = periods[row.period]
        demand[r_idx,t,p_idx] = row.demand
    end

    return market(demand, pricecap)

end

welfare(x::Markets) =
    welfare(x.capacity) + welfare(x.rec) + welfare(x.energy) +
    welfare(x.raisereserve) + welfare(x.lowerreserve)
