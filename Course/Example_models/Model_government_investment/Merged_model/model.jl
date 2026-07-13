module VietnamMergedModel

import JuMP
using JuMP: Model, set_silent
using Ipopt
using SquareModels

include(joinpath(@__DIR__, "..", "sets.jl"))
include(joinpath(@__DIR__, "Variables.jl"))

model_ref(vars, name::Symbol, year) =
    getproperty(vars, name)[year]

model_ref(vars, key::Tuple, year) =
    getproperty(vars, first(key))[Base.tail(key)..., year]

function set_data!(db, vars, data)
    for (key, value) in data.initial
        db[model_ref(vars, key, data.base_year)] = value
    end

    for inputs in (
        data.paths,
        data.growth,
        data.parameters,
    )
        for (key, values) in inputs
            for (year, value) in zip(
                data.projection_years,
                values,
            )
                db[model_ref(vars, key, year)] = value
            end
        end
    end

    return db
end

include(joinpath(@__DIR__, "modules", "GoodsMarketAndPrivateSector.jl",))
include(joinpath(@__DIR__, "modules", "GovernmentBudget.jl",))
include(joinpath(@__DIR__, "modules", "MoneyMarket.jl",))
include(joinpath(@__DIR__, "modules", "BalanceOfPayments.jl",))

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
        MODEL_SETS,
        years,
        projection_periods,
    )

    goods_market_and_private_sector =
        GoodsMarketAndPrivateSector.define_equations(
            db,
            vars;
            sectors = MODEL_SETS.sectors,
            proj = projection_periods,
            base_period = base_year,
        )

    government_budget =
        GovernmentBudget.define_equations(
            db,
            vars;
            public_investment_types =
                MODEL_SETS.public_investment_types,
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
        outputs[key] = Dict(
            year => Float64(
                solution[model_ref(vars, key, year)],
            )
            for year in projection_periods
        )
    end

    return outputs
end

end