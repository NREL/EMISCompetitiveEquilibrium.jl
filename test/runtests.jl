using CompetitiveEquilibriumInvestments
using Gurobi
using Test

@testset "Toy Problem" begin

    R = 3
    T = 12
    P = 4

    # Generation / Storage Technologies

    thermaltechs = ThermalGenerators(
        ["Tech A"], ["Firm 1"], [5.], [15.], [6], [6], [5.], [5.], [0.95])

    variabletechs = VariableGenerators(String[], String[], Float64[])

    storagetechs = StorageDevices(
        String[], String[], Float64[], Float64[], Float64[],
        Float64[], Float64[], Float64[], Float64[])

    interfaces = Interfaces{R}(["1-2", "1-3", "2-3"], [(1,2), (1,3), (2,3)])

    techs = Technologies(thermaltechs, variabletechs, storagetechs, interfaces)

    # Initial Conditions

    thermalstart = InitialInvestments(zeros(Int, 3, 1), zeros(Int, 3, 1))
    emptystart = InitialInvestments(zeros(Int, 3, 0), zeros(Int, 3, 0))

    initconds = InitialConditions(thermalstart, emptystart, emptystart)


    # Investment Context

    inv_thermal = ResourceInvestments(
        [1000.], [10000.], [0.], [1], [1], fill(0, 3, 1), fill(0, 3, 1))

    inv_empty = ResourceInvestments(
        Float64[], Float64[], Float64[], Int[], Int[],
        zeros(Int, 3, 0), zeros(Int, 3, 0))

    invs = Investments(inv_thermal, inv_empty, inv_empty)


    # Operating Context

    ops_thermal =
        ThermalGeneratorOperations{R,T,P}([200.], [4.], [2.], [2.])

    ops_variable =
        VariableGeneratorOperations(
            Float64[], Float64[], Array{Float64}(undef, R, 0, T, P))

    ops_storage =
        StorageOperations{R,T,P}(Float64[], Float64[])

    ops_transmission =
        TransmissionOperations{R,T,P}([10., 10, 10])

    ops = Operations(ops_thermal, ops_variable, ops_storage, ops_transmission)


    # Market Context

    base = [10. 15 20 25 30 35 36 31 26 21 16 11]
    r_scale = [1.0, 0.9, 1.1]
    p_scale = reshape([0.8, 1.0, 1.2, 1.4], 1, 1, P)
    load = base .* r_scale .* p_scale
    reserve = 0.1 .* load

    capacity = CapacityMarket(1000., 40., -100.)
    energy = EnergyMarket(load, 1e5)
    raisereserve = RaiseReserveMarket(reserve, 4e4)
    lowerreserve = LowerReserveMarket(reserve, 4e4)

    markets = Markets(capacity, energy, raisereserve, lowerreserve)

    periodweights = fill(13., 4)

    # InvestmentProblem

    discountrate = 0.98
    p = InvestmentProblem(techs, initconds, discountrate,
                          invs, ops, markets, periodweights, Gurobi.Optimizer)

    solve!(p)

end

@testset "RTS" begin
    p = InvestmentProblem("/home/gord/work/EMIS/EMISPreprocessing/output", Gurobi.Optimizer)
    solve!(p)
end
