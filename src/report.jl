function report(
    reportdir::String, invprob::InvestmentProblem{R,G1,G2,G3,I,T,P}
) where {R,G1,G2,G3,I,T,P}

    status = termination_status(invprob.model)

    if status != MOI.OPTIMAL
        status == MOI.OPTIMIZE_NOT_CALLED && error("Model has not yet been solved")
        error("Model was not solved to optimality: status is $(status)")
    end

    isdir(reportdir) || mkpath(reportdir)

    demands = DataFrame(scenario=String[], market=String[],
                        region=String[],
                        period=String[], timestep=Int[], value=Float64[])

    dispatches = DataFrame(scenario=String[], market=String[],
                           region=String[], gen=String[], 
                           period=String[], timestep=Int[], value=Float64[])

    for (scenario, isleaf) in scenarios(invprob)

        for market in [:energydispatch, :raisereserve, :lowerreserve],
            (r, regionname) in enumerate(invprob.regionnames),
            gentype in [:thermal, :variable, :storage]

            gennames = getfield(invprob.technologies, gentype).name

            dispatch = if gentype == :storage
                if market == :energydispatch
                    scenario.operations.storage.energydischarge .-
                    scenario.operations.storage.energycharge
                else
                    getfield(scenario.operations.storage, market)
                end
            else
                getfield(getfield(scenario.operations, gentype), market)
            end

            marketname = market == :energydispatch ? "energy" : string(market)
 

            for (g, genname) in enumerate(gennames),
                (p, periodname) in enumerate(invprob.periodnames),
                t in 1:T

                    push!(dispatches,
                          (scenario=scenario.name, market=marketname,
                           region=regionname, gen=genname,
                           period=periodname, timestep=t,
                           value=value(dispatch[r,g,t,p])))

            end

        end

        for market in [:energy, :raisereserve, :lowerreserve],
            (r, regionname) in enumerate(invprob.regionnames)

            demand = getfield(scenario.markets, market).demand

            for (p, periodname) in enumerate(invprob.periodnames), t in 1:T

                push!(demands, (scenario=scenario.name, market=string(market),
                                region=regionname,
                                period=periodname, timestep=t,
                                value=demand[r,t,p]))

            end

        end

        if isleaf

            # TODO: Quantile plot of energy prices for each leaf scenario?

            # Save series of buildout progressions, by leaf scenario

            scen = scenario
            buildouts = DataFrame[]

            while !isnothing(scen)
                push!(buildouts, investmentstates(scenario))
                scen = scen.parent
            end

            CSV.write(joinpath(reportdir, "buildouts_$(scenario.name).csv"),
                      vcat(reverse(buildouts)...))

        end

    end

    dispatches.value[-1e-10 .< dispatches.value .< 0] .= 0.
    CSV.write(joinpath(reportdir, "dispatch.csv"), dispatches)
    CSV.write(joinpath(reportdir, "demand.csv"), demands)

end

function investmentstates(scen::Scenario)

    result = DataFrame(
        scenario=String[], tech=String[], state=String[], count=Int[])

    for techtype in [:thermal, :variable, :storage]

        techs = getfield(scen.investmentproblem.technologies, techtype)
        investments = getfield(scen.investments, techtype)

        for state in [:vesting, :buildable, :building, :dispatchable, :retired]

            counts = round.(Int, value.(getfield(investments, state)))

            for (i, tech) in enumerate(techs.name)
                push!(result, (scenario=scen.name, tech=tech,
                               state=string(state),
                               count=sum(counts[:, i])))
            end
            
        end

    end

    return result

end
