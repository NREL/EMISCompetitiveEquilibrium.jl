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

welfare(x::Markets) =
    welfare(x.capacity) + welfare(x.energy) +
    welfare(x.raisereserve) + welfare(x.lowerreserve)
