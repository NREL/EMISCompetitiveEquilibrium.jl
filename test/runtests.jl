using CompetitiveEquilibriumInvestments
using JuMP
using Gurobi
using Test

const CEI = CompetitiveEquilibriumInvestments

function fix_discrete_reoptimize!(m::Model, solver)

    # Go through all variables and fix binaries / integers
    # such that the problem is convex and has duals
    vars = all_variables(m)
    vals = value.(vars)
    for (var, val) in zip(vars, vals)
        if is_binary(var) || is_integer(var)
            is_binary(var) ? unset_binary(var) : unset_integer(var)
            fix(var, val, force=true)
        end
    end

    set_optimizer(m, solver)
    @time optimize!(m)

    return m

end

true && @testset "Toy Problem" begin

    R = 3
    G1 = 1
    G2 = 0
    G3 = 0
    I = 3
    T = 12
    P = 4

    periodnames = ["P$i" for i in 1:P]
    regionnames = ["A", "B", "C"]

    # Generation / Storage Technologies

    thermaltechs = ThermalGenerators(
        ["Tech A"], ["Firm 1"], [5.], [15.], [6], [6], [5.], [5.], [0.95])

    variabletechs = VariableGenerators(String[], String[], Float64[], Float64[])

    storagetechs = StorageDevices(
        String[], String[], Float64[], Float64[], Float64[],
        Float64[], Float64[], Float64[], Float64[])

    interfaces = Interfaces{R}(["1-2", "1-3", "2-3"], [(1,2), (1,3), (2,3)])

    techs = Technologies(thermaltechs, variabletechs, storagetechs, interfaces)

    # Initial Conditions

    thermalstart = InitialInvestments(zeros(Int, R, G1), zeros(Int, R, G1))
    emptystart = InitialInvestments(zeros(Int, R, 0), zeros(Int, R, 0))
    initconds = InitialConditions(thermalstart, emptystart, emptystart)


    # Investment Context

    inv_thermal = ResourceInvestments(
        fill(1000., R, G1), fill(10000., R, G1), fill(0., R, G1),
        fill(1, R, G1), fill(1, R, G1), fill(0, R, G1), fill(0, R, G1),
        fill(0, R, G1))

    inv_empty = ResourceInvestments(
        zeros(Float64, R, 0), zeros(Float64, R, 0), zeros(Float64, R, 0),
        zeros(Int, R, 0), zeros(Int, R, 0), zeros(Int, R, 0), zeros(Int, R, 0),
        zeros(Int, R, 0))

    invs = Investments(inv_thermal, inv_empty, inv_empty)


    # Operating Context

    ops_thermal =
        ThermalGeneratorOperations{T,P}(fill(200., R, G1), fill(4., R, G1),
                                        fill(2., R, G1), fill(2., R, G1))

    ops_variable =
        VariableGeneratorOperations(
            zeros(Float64, R, G2), zeros(Float64, R, G2),
            zeros(Float64, R, G2, T, P))

    ops_storage =
        StorageOperations{T,P}(zeros(Float64, R, G3), zeros(Float64, R, G3))

    ops_transmission =
        TransmissionOperations{R,T,P}([10., 10, 10])

    ops = Operations(ops_thermal, ops_variable, ops_storage, ops_transmission)


    # Market Context

    base = [10. 15 20 25 30 35 36 31 26 21 16 11]
    r_scale = [1.0, 0.9, 1.1]
    p_scale = reshape([0.8, 1.0, 1.2, 1.4], 1, 1, P)
    load = base .* r_scale .* p_scale
    reserve = 0.1 .* load

    capacity = CapacityMarket(1000., 500., 10., 15., 20.)
    rec = RECMarket(0., 50.)
    energy = EnergyMarket(load, fill(1e5, R))
    raisereserve = RaiseReserveMarket(reserve, fill(4e4, R))
    lowerreserve = LowerReserveMarket(reserve, fill(4e4, R))

    markets = Markets(capacity, rec, energy, raisereserve, lowerreserve)

    periodweights = fill(13., 4)

    # InvestmentProblem

    discountrate = 0.98
    p = InvestmentProblem(regionnames, periodnames, techs, initconds,
                          discountrate, "RootScenario",
                          invs, ops, markets, periodweights, Gurobi.Optimizer)
    solve!(p)
    fix_discrete_reoptimize!(p.model, Gurobi.Optimizer)
    report(joinpath(dirname(@__FILE__), "toymodel"), p)

end

true && @testset "RTS" begin
    p = InvestmentProblem(
        "/home/gord/work/EMIS/EMISPreprocessing/output",
        optimizer_with_attributes(Gurobi.Optimizer,
            "MIPGap" => 0.005, "MIPGapAbs" => 100e6))
    solve!(p, debug=true)
    fix_discrete_reoptimize!(p.model, Gurobi.Optimizer)
    report(joinpath(dirname(@__FILE__), "rts"), p)
end
