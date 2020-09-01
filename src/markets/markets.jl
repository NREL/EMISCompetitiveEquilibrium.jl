include("capacity.jl")
include("energy.jl")
include("raisereserve.jl")
include("lowerreserve.jl")

struct Markets{R,T,P}
   capacity::CapacityMarket
   energy::EnergyMarket{R,T,P}
   raisereserve::RaiseReserveMarket{R,T,P}
   lowerreserve::LowerReserveMarket{R,T,P}
end

function loadmarkets(
    regions::Dict{String,Int}, periods::Dict{String,Int}, n_timesteps::Int,
    resourcepath::String
)
    capacity = CapacityMarket(join(resourcepath, "capacity"))

    energy = loadmarket(
        EnergyMarket, regions, periods, n_timesteps,
        join(resourcepath, "energy"))

    raisereserve = loadmarket(
        RaiseReserveMarket, regions, periods, n_timesteps,
        join(resourcepath, "raisereserve"))

    lowerreserve = loadmarket(
        LowerReserveMarket, regions, periods, n_timesteps,
        join(resourcepath, "lowerreserve"))

    return Markets(capacity, energy, raisereserve, lowerreserve)

end

function loadmarket(
    market::Type, regions::Dict{String,Int}, periods::Dict{String,Int}, T::Int,
    marketpath::String
)

    rulesdata = DataFrame!(CSV.File(joinpath(marketpath, "rules.csv")))
    demanddata = DataFrame!(CSV.File(joinpath(marketpath, "demand.csv")))

    demanddata = stack(energydemanddata, Not([:period, :timestep]),
                       variable_name=:region, value_name=:demand)

    R = length(regions)
    P = length(periods)

    demand = zeros(Float64, R, T, P)

    for row in eachrow(demanddata)
        r_idx = regions[row.region]
        t = row.timestep
        p_idx = periods[row.period]
        demand[r_idx,t,p_idx] = row.demand
    end

    pricecap = first(rulesdata.pricecap) # TODO: Fix this, should be by region

    return market{R,T,P}(demand, pricecap)

end

welfare(x::Markets) =
    welfare(x.capacity) + welfare(x.energy) +
    welfare(x.raisereserve) + welfare(x.lowerreserve)
