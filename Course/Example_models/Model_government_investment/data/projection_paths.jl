# ==============================================================================
# Projection paths
# ==============================================================================

path(x::Number, years) =
    fill(Float64(x), length(years))

path(x::AbstractVector, years) =
    Float64.(x)

path(x::AbstractDict, years) =
    Float64[
        haskey(x, year) ? x[year] : x[:default]
        for year in years
    ]

compound_path(x0, growth, years) =
    Float64(x0) .* accumulate(*, 1 .+ path(growth, years))

indexed_paths(name, values, years) =
    Dict(
        (name, index) => path(value, years)
        for (index, value) in values
    )

function build_projection_paths(
    base::BaseYearState,
    assumptions;
    horizon::Int,
)
    years = collect(
        (base.year + 1):(base.year + horizon),
    )

    p(x) = path(x, years)

    E_growth = p(assumptions.exchange_rate_growth)
    PD_growth = p(assumptions.domestic_price_growth)

    # Foreign prices keep the real exchange rate constant.
    foreign_price_growth =
        (1 .+ PD_growth) ./
        (1 .+ E_growth) .-
        1

    growth = merge(
        indexed_paths(
            :gamma,
            assumptions.gdp_growth,
            years,
        ),
        indexed_paths(
            :xgr,
            assumptions.export_growth,
            years,
        ),
        indexed_paths(
            :ivggr,
            assumptions.government_investment_growth,
            years,
        ),
    )

    growth_rates = (
        E = E_growth,
        PD = PD_growth,
        MPI = foreign_price_growth,
        XPI = foreign_price_growth,

        GT = PD_growth,
        TG = assumptions.government_revenue_growth,
        NDDG = assumptions.government_domestic_debt_growth,

        NFP = assumptions.net_factor_payments_growth,
        NTRG = assumptions.government_transfers_growth,
        NTRP = assumptions.private_transfers_growth,
        FDI = assumptions.foreign_direct_investment_growth,
    )

    paths = Dict(
        name => compound_path(
            base.values[name],
            growth,
            years,
        )
        for (name, growth) in pairs(growth_rates)
    )

    c = base.calibrated

    parameters = Dict(
        :b => p(c[:b_calibrated]),
        :d => p(assumptions.reserve_change_import_change_response),
        :g => p(c[:g]),
        :k0 => p(c[:k0]),
        :m0 => p(c[:m0]),
        :v => p(c[:v]),

        :k1 => p(assumptions.investment_growth_coefficient),
        :m1 => p(assumptions.import_gdp_elasticity),
        :m2 => p(assumptions.import_real_exchange_rate_elasticity),

        :irdg =>
            c[:irdg] .+
            p(assumptions.government_domestic_rate_adjustment),

        :irfg =>
            c[:irfg] .+
            p(assumptions.government_foreign_rate_adjustment),

        :irfp =>
            c[:irfp] .+
            p(assumptions.private_foreign_rate_adjustment),
    )

    return (; growth, paths, parameters)
end