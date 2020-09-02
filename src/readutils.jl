const initialcondition_types = Dict(
    :class=>String, :region=>String, :built=>Int, :optioned=>Int
)

const period_types = Dict(
    :name=>String, :weight=>Float64
)

const scenarios_tree_types = Dict(
    :name=>String,
    :parent=>String,
    :probability=>Float64
)

# TODO: Thermal / variable / storage technical types?

const scenarios_resource_param_types = Dict(
    :class=>String, :region=>String,
    :variablecost=>Float64, :fixedcost=>Float64,
    :startupcost=>Float64, :shutdowncost=>Float64,
    :optioncost=>Float64, :buildcost=>Float64, :retirementcost=>Float64,
    :buildleadtime=>Int, :optionleadtime=>Int,
    :newoptionslimit=>Int, :newbuildslimit=>Int
)

const scenarios_transmission_param_types = Dict(
    :interface=>String, :limit=>Float64)

const scenarios_market_param_types = Dict(
    :region=>String, :pricecap=>Float64)

const scenarios_capacitymarket_param_types = Dict(
    :targetprice=>Float64, :targetcapacity=>Float64, :demandslope=>Float64)

