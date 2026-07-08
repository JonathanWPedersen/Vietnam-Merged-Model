# ==============================================================================
# Base-year reconstruction
# ==============================================================================

struct BaseYearState
    year::Int
    lag_year::Int

    values::Dict{Any, Float64}
    lag::Dict{Any, Float64}
    calibrated::Dict{Symbol, Float64}

    sam::SAM
end

# ==============================================================================
# Prices and historical model levels
# ==============================================================================

function model_price_indices(
    raw::RawInputs,
    assumptions,
    year::Int,
    base_year::Int,
)
    nominal = observed_value(
        raw,
        "GSO national accounts — nominal expenditure",
        "Nominal GDP",
        year,
    )

    real = observed_value(
        raw,
        "GSO national accounts — real expenditure",
        "Real GDP",
        year,
    )

    base_nominal = observed_value(
        raw,
        "GSO national accounts — nominal expenditure",
        "Nominal GDP",
        base_year,
    )

    base_real = observed_value(
        raw,
        "GSO national accounts — real expenditure",
        "Real GDP",
        base_year,
    )

    base_PD = Float64(
        assumptions.base_year_domestic_price_index,
    )

    base_MPI = Float64(
        assumptions.base_year_import_price_index,
    )

    base_XPI = Float64(
        assumptions.base_year_export_price_index,
    )

    relative_price =
        (nominal / real) /
        (base_nominal / base_real)

    return (
        PD = base_PD * relative_price,
        MPI = base_MPI * relative_price,
        XPI = base_XPI * relative_price,
    )
end

function model_level_state(
    raw::RawInputs,
    assumptions,
    year::Int,
    base_year::Int,
)
    prices = model_price_indices(
        raw,
        assumptions,
        year,
        base_year,
    )

    stocks = build_stock_state(
        raw,
        assumptions,
        year,
    )

    trade = aggregate_external_trade(raw, year)

    GDP = stocks[:GDPN] / prices.PD

    return Dict{Symbol, Float64}(
        :E => stocks[:E],

        :PD => prices.PD,
        :MPI => prices.MPI,
        :XPI => prices.XPI,

        :GDP => GDP,
        :GDPN => stocks[:GDPN],

        :X => 1_000 * trade.exports_bn_usd / prices.XPI,
        :M => 1_000 * trade.imports_bn_usd / prices.MPI,

        :DCP => stocks[:DCP],
        :DCG => stocks[:DCG],
        :DC => stocks[:DC],

        :MD => stocks[:MD],
        :MS => stocks[:MS],
        :R => stocks[:R],

        :NDDG => stocks[:NDDG],
        :NFDG => stocks[:NFDG],
        :NFDP => stocks[:NFDP],
    )
end

function sectoral_GDP_shares(
    raw::RawInputs,
    year::Int,
)
    group = "GSO national accounts — real sector GDP"

    sector_values = Dict(
        :agriculture => observed_value(
            raw,
            group,
            "Agriculture GDP",
            year,
        ),
        :industry => observed_value(
            raw,
            group,
            "Industry GDP",
            year,
        ),
        :services => observed_value(
            raw,
            group,
            "Services GDP",
            year,
        ),
    )

    total = sum(Base.values(sector_values))

    return Dict(
        sector => sector_values[sector] / total
        for sector in SAM_SECTORS
    )
end

function sectoral_export_shares(
    raw::RawInputs,
    year::Int,
)
    sector_values = observed_sector_exports(raw, year)

    total = sum(Base.values(sector_values))

    return Dict(
        sector => sector_values[sector] / total
        for sector in SAM_SECTORS
    )
end

# ==============================================================================
# Main base-year builder
# ==============================================================================

function build_base_year(
    raw::RawInputs,
    assumptions,
    sam::SAM;
    year::Int,
)
    year == sam.year || error(
        "SAM year $(sam.year) does not match requested base year $year.",
    )

    lag_year = year - 1

    current = model_level_state(
        raw,
        assumptions,
        year,
        year,
    )

    lag = model_level_state(
        raw,
        assumptions,
        lag_year,
        year,
    )

    for name in (:NDDG, :NFDG, :NFDP)
        lag[name] = sam.lag[name]
    end

    flows = sam.flows
    values = Dict{Any, Float64}()

    for name in (
        :E,
        :PD,
        :MPI,
        :XPI,
        :GDP,
        :GDPN,
        :X,
        :M,
        :DCP,
        :DCG,
        :DC,
        :MD,
        :MS,
        :R,
        :NDDG,
        :NFDG,
        :NFDP,
    )
        values[name] = current[name]
    end

    values[:P] = values[:GDPN] / values[:GDP]

    for name in (
        :GT,
        :TG,
        :IVG,
        :NTRG,
        :NTRP,
        :FDI,
        :NFP,
        :INFG,
        :INFP,
        :INDG,
    )
        values[name] = flows[name]
    end

    GDP_shares = sectoral_GDP_shares(raw, year)
    export_shares = sectoral_export_shares(raw, year)

    for sector in SAM_SECTORS
        values[(:GDPS, sector)] =
            GDP_shares[sector] * values[:GDP]

        values[(:XS, sector)] =
            export_shares[sector] * values[:X]
    end

    values[:CP] = flows[:CP]
    values[:CG] = flows[:CG]
    values[:C] = values[:CP] + values[:CG]

    values[:IV] = flows[:IV]
    values[:IVP] = flows[:IVP]

    values[:RESBAL] =
        values[:XPI] * values[:X] -
        values[:MPI] * values[:M]

    values[:NETFSY] =
        values[:NFP] -
        values[:INFG] -
        values[:INFP]

    values[:CURBAL] =
        values[:RESBAL] +
        values[:NETFSY] +
        values[:NTRG] +
        values[:NTRP]

    values[:GDY] =
        values[:P] * values[:GDP] +
        values[:E] * values[:NFP] +
        values[:E] * values[:NTRP] +
        values[:INDG] +
        (values[:GT] - values[:TG]) -
        values[:E] * values[:INFP]

    values[:GDS] =
        values[:P] * values[:GDP] +
        values[:E] * (
            values[:NFP] -
            values[:INFG] -
            values[:INFP]
        ) +
        values[:E] * (
            values[:NTRP] +
            values[:NTRG]
        ) -
        values[:PD] * values[:C]

    values[:BRG] =
        values[:PD] * (
            values[:CG] +
            values[:IVG]
        ) +
        (values[:GT] - values[:TG]) +
        values[:INDG] +
        values[:E] * (
            values[:INFG] -
            values[:NTRG]
        )

    # ==========================================================================
    # Parameter calibration
    # ==========================================================================

    k1 = Float64(assumptions.investment_growth_coefficient)
    m1 = Float64(assumptions.import_gdp_elasticity)
    m2 = Float64(
        assumptions.import_real_exchange_rate_elasticity,
    )

    saving_adjustment = Float64(
        assumptions.base_year_private_saving_adjustment,
    )

    b_calibrated =
        flows[:private_saving] /
        (
            values[:CP] +
            flows[:private_saving]
        )

    b_base = b_calibrated + saving_adjustment

    d =
        (
            flows[:reserve_related_financial_flow] /
            values[:E]
        ) /
        (
            values[:MPI] * values[:M] -
            lag[:MPI] * lag[:M]
        )

    g =
        values[:NFDG] /
        (
            values[:XPI] *
            values[:X]
        )

    k0 =
        (
            values[:IV] -
            k1 * (
                values[:GDP] -
                lag[:GDP]
            )
        ) /
        lag[:GDP]

    m0 =
        log(values[:M]) -
        m1 * log(values[:GDP]) -
        m2 * log(
            values[:E] *
            values[:MPI] /
            values[:PD],
        )

    v = values[:GDPN] / values[:MS]

    irdg = values[:INDG] / lag[:NDDG]
    irfg = values[:INFG] / lag[:NFDG]
    irfp = values[:INFP] / lag[:NFDP]

    calibrated = Dict{Symbol, Float64}(
        :b_calibrated => b_calibrated,
        :b_base => b_base,

        :d => d,
        :g => g,

        :k0 => k0,
        :k1 => k1,

        :m0 => m0,
        :m1 => m1,
        :m2 => m2,

        :v => v,

        :irdg => irdg,
        :irfg => irfg,
        :irfp => irfp,
    )

    return BaseYearState(
        year,
        lag_year,
        values,
        lag,
        calibrated,
        sam,
    )
end