# R: number of regions
# G: number of generators (either thermal / VG / storage)
# T: number of operations timesteps per period
# P: number of operations periods

mutable struct InvestmentProblem{R,G1,G2,G3,T,P} <: AbstractProblem{R,G1,G2,G3,T,P}

    model::Model

    technologies::Technologies{G1,G2,G3}
    initialconditions::InitialConditions{R,G1,G2,G3}

    discountrate::Float64

    rootscenario::Scenario{R,G1,G2,G3,T,P}

    InvestmentProblem{T,P}(
        model::Model,
        techs::Technologies{G1,G2,G3},
        initconds::InitialConditions{R,G1,G2,G3},
        discountrate::Float64
    ) where {R,G1,G2,G3,T,P} =
        new{R,G1,G2,G3,T,P}(model, techs, initconds, discountrate)

end

function InvestmentProblem(
    techs::Technologies{G1,G2,G3},
    initconds::InitialConditions{R,G1,G2,G3},
    discountrate::Float64,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,T,P},
    markets::Markets{R,T,P}
) where {R,G1,G2,G3,T,P}

    invprob = InvestmentProblem{T,P}(
        Model(), techs, initialconds, discountrate)

    root = Scenario(invprob, investments, operations, markets)
    invprob.rootscenario = root

    return invprob

end

function solve!(invprob::InvestmentProblem)
    @objective(invprob.m, Max, welfare(invprob.rootscenario))
    optimize!(invprob.model)
    return
end
