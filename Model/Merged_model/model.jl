module VietnamMergedModel

import JuMP
using JuMP: Model, set_silent
using Ipopt
using SquareModels

const SECTORS = [:agriculture, :industry, :services]

include(joinpath(@__DIR__, "Variables.jl"))

function set_path!(db, variable, values, years)
    for (year, value) in zip(years, values)
        db[variable[year]] = value
    end
end

function set_data!(db, v, data)
    t0 = data.base_year
    t = data.projection_years

    for (name, value) in data.initial
        name isa Symbol || continue
        db[getproperty(v, name)[t0]] = value
    end

    for sector in SECTORS
        db[v.GDPS[sector, t0]] = data.initial[(:GDPS, sector)]
        db[v.XS[sector, t0]] = data.initial[(:XS, sector)]

        for (year, value) in zip(
            t,
            data.growth[(:gamma, sector)],
        )
            db[v.gamma[sector, year]] = value
        end

        for (year, value) in zip(
            t,
            data.growth[(:xgr, sector)],
        )
            db[v.xgr[sector, year]] = value
        end
    end

    for (name, values) in data.paths
        set_path!(db, getproperty(v, name), values, t)
    end

    for (name, values) in data.parameters
        set_path!(db, getproperty(v, name), values, t)
    end

    return db
end

include(joinpath(@__DIR__, "modules", "GoodsMarketAndPrivateSector.jl"))
include(joinpath(@__DIR__, "modules", "GovernmentBudget.jl"))
include(joinpath(@__DIR__, "modules", "MoneyMarket.jl"))
include(joinpath(@__DIR__, "modules", "BalanceOfPayments.jl"))

function build_square_model(
    base_year::Int,
    horizon::Int,
)
    years = base_year:(base_year + horizon)
    projection_periods = (base_year + 1):(base_year + horizon)

    db = ModelDictionary(Model(Ipopt.Optimizer))
    set_silent(db.model)

    vars = declare_variables!(
        db,
        SECTORS,
        years,
        projection_periods,
    )

    goods_market_and_private_sector =
        GoodsMarketAndPrivateSector.define_equations(
            db,
            vars;
            sectors = SECTORS,
            proj = projection_periods,
            base_period = base_year,
        )

    government_budget =
        GovernmentBudget.define_equations(
            db,
            vars;
            proj = projection_periods,
        )

    money_market =
        MoneyMarket.define_equations(
            db,
            vars;
            proj = projection_periods,
        )

    balance_of_payments =
        BalanceOfPayments.define_equations(
            db,
            vars;
            proj = projection_periods,
        )

    full_model =
        goods_market_and_private_sector +
        government_budget +
        money_market +
        balance_of_payments

    blocks = (;
        goods_market_and_private_sector,
        government_budget,
        money_market,
        balance_of_payments,
        full_model,
    )

    return db, vars, blocks
end

function extract_outputs(
    solution,
    vars,
    projection_periods,
)
    outputs = Dict{Any, Dict{Int, Float64}}()

    for key in OUTPUT_KEYS
        name = key isa Tuple ? key[1] : key
        indices = key isa Tuple ? key[2:end] : ()

        outputs[key] = Dict(
            year => Float64(
                solution[getproperty(vars, name)[indices..., year]],
            )
            for year in projection_periods
        )
    end

    return outputs
end

end