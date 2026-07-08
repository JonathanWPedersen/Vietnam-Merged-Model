# ==============================================================================
# Projection paths
# ==============================================================================

constant_path(x, horizon) = fill(Float64(x), horizon)

compound_path(x0, growth, horizon) =
    Float64(x0) .* (1 + Float64(growth)) .^ (1:horizon)

function build_projection_paths(
    base::BaseYearState,
    assumptions;
    horizon::Int,
)
    E_growth = assumptions.exchange_rate_growth
    PD_growth = assumptions.domestic_price_growth

    foreign_price_growth =
        (1 + PD_growth) / (1 + E_growth) - 1

    growth = Dict(
        (:gamma, :agriculture) =>
            constant_path(assumptions.agriculture_gdp_growth, horizon),

        (:gamma, :industry) =>
            constant_path(assumptions.industry_gdp_growth, horizon),

        (:gamma, :services) =>
            constant_path(assumptions.services_gdp_growth, horizon),

        (:xgr, :agriculture) =>
            constant_path(assumptions.agriculture_export_growth, horizon),

        (:xgr, :industry) =>
            constant_path(assumptions.industry_export_growth, horizon),

        (:xgr, :services) =>
            constant_path(assumptions.services_export_growth, horizon),
    )

    paths = Dict(
        :E => compound_path(base.values[:E], E_growth, horizon),
        :PD => compound_path(base.values[:PD], PD_growth, horizon),
        :MPI => compound_path(
            base.values[:MPI],
            foreign_price_growth,
            horizon,
        ),
        :XPI => compound_path(
            base.values[:XPI],
            foreign_price_growth,
            horizon,
        ),

        :GT => compound_path(base.values[:GT], PD_growth, horizon),
        :TG => compound_path(
            base.values[:TG],
            assumptions.government_revenue_growth,
            horizon,
        ),
        :IVG => compound_path(
            base.values[:IVG],
            assumptions.government_investment_growth,
            horizon,
        ),
        :NDDG => compound_path(
            base.values[:NDDG],
            assumptions.government_domestic_debt_growth,
            horizon,
        ),

        :NFP => compound_path(
            base.values[:NFP],
            assumptions.net_factor_payments_growth,
            horizon,
        ),
        :NTRG => compound_path(
            base.values[:NTRG],
            assumptions.government_transfers_growth,
            horizon,
        ),
        :NTRP => compound_path(
            base.values[:NTRP],
            assumptions.private_transfers_growth,
            horizon,
        ),
        :FDI => compound_path(
            base.values[:FDI],
            assumptions.foreign_direct_investment_growth,
            horizon,
        ),
    )

    parameters = Dict(
        :b => constant_path(base.calibrated[:b_calibrated], horizon),
        :d => constant_path(
            assumptions.reserve_change_import_change_response,
            horizon,
        ),

        :g => constant_path(base.calibrated[:g], horizon),
        :k0 => constant_path(base.calibrated[:k0], horizon),
        :m0 => constant_path(base.calibrated[:m0], horizon),
        :v => constant_path(base.calibrated[:v], horizon),

        :k1 => constant_path(
            assumptions.investment_growth_coefficient,
            horizon,
        ),
        :m1 => constant_path(
            assumptions.import_gdp_elasticity,
            horizon,
        ),
        :m2 => constant_path(
            assumptions.import_real_exchange_rate_elasticity,
            horizon,
        ),

        :irdg =>
            base.calibrated[:irdg] .+
            constant_path(
                assumptions.government_domestic_rate_adjustment,
                horizon,
            ),

        :irfg =>
            base.calibrated[:irfg] .+
            constant_path(
                assumptions.government_foreign_rate_adjustment,
                horizon,
            ),

        :irfp =>
            base.calibrated[:irfp] .+
            constant_path(
                assumptions.private_foreign_rate_adjustment,
                horizon,
            ),
    )

    return (; growth, paths, parameters)
end