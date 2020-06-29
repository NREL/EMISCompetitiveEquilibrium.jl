struct Scenario{R,G1,G2,G3,T,P}

    probability::Float64
    parentscenario::Union{Scenario{R,G1,G2,G3,T,P},Nothing}
    childscenarios::Vector{Scenario{R,G1,G2,G3,T,P}}
    investmentproblem::InvestmentProblem{R,G1,G2,G3,T,P}

    investments::Investments{R,G1,G2,G3}
    operations::Operations{R,G1,G2,G3,T,P}
    markets::Markets{R,T,P}

end

function Scenario(
    parent::Scenario, p::Float64,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,T,P},
    markets::Markets{R,T,P}
) where {R,G1,G2,G3,T,P}

    s = Scenario(
        p, parent, Scenario{R,G1,G2,G3,T,P}[], parent.investmentproblem,
        investments, operations, markets)

    setupinvestments!(s)
    setupoperations!(s)
    setupmarkets!(s)

    return s

end

function Scenario(
    invprob::InvestmentProblem,
    investments::Investments{R,G1,G2,G3},
    operations::Operations{R,G1,G2,G3,T,P},
    markets::Markets{R,T,P}
) where {R,G1,G2,G3,T,P}

    s = Scenario(1.0, nothing, Scenario{R,G1,G2,G3,T,P}[], invprob,
                 investments, operations, markets)

    setupinvestments!(s)
    setupoperations!(s)
    setupmarkets!(s)

    return s

end


welfare(s::Scenario) =
    welfare(s.investments) + welfare(s.operations) + welfare(s.markets) +
    s.investmentproblem.discountrate *
    sum(cs.probability * welfare(cs) for cs in s.childscenarios)
