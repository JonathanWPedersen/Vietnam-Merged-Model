struct BaseYearState
    year::Int
    lag_year::Int

    values::Dict{Any, Float64}
    lag::Dict{Symbol, Float64}
    calibrated::Dict{Symbol, Float64}

    sam::SAM
end

# ==============================================================================
# Prices and levels
# ==============================================================================

function model_price_indices(obs, assumptions, year, base_year)
    deflator(y) =
        read_group(obs, NATIONAL_ACCOUNTS, y).GDPN /
        read_group(obs, REAL_ACCOUNTS, y).GDP_real

    relative_price = deflator(year) / deflator(base_year)

    return (
        PD = assumptions.base_year_domestic_price_index * relative_price,
        MPI = assumptions.base_year_import_price_index * relative_price,
        XPI = assumptions.base_year_export_price_index * relative_price,
    )
end

function model_level_state(obs, assumptions, year, base_year)
    prices = model_price_indices(obs, assumptions, year, base_year)
    stocks = build_stock_state(obs, assumptions, year)
    trade = aggregate_external_trade(obs, year)

    state = Dict{Symbol, Float64}(
        :E => stocks[:E],

        :PD => prices.PD,
        :MPI => prices.MPI,
        :XPI => prices.XPI,

        :GDP => stocks[:GDPN] / prices.PD,
        :GDPN => stocks[:GDPN],

        :X => trade.exports / prices.XPI,
        :M => trade.imports / prices.MPI,
    )

    for name in (:DCP, :DCG, :DC, :MD, :MS, :R, :NDDG, :NFDG, :NFDP)
        state[name] = stocks[name]
    end

    return state
end

"Normalise sectoral values to shares of their own total."
function sector_shares(values, sectors)
    total = sum(values[sector] for sector in sectors)
    return Dict(sector => values[sector] / total for sector in sectors)
end

# ==============================================================================
# Calibration
# ==============================================================================

function calibrate_parameters(v, lag, flows, assumptions)
    k1 = assumptions.investment_growth_coefficient
    m1 = assumptions.import_gdp_elasticity
    m2 = assumptions.import_real_exchange_rate_elasticity

    # Private saving rate
    b_calibrated = flows[:private_saving] / (v[:CP] + flows[:private_saving])
    b_base = b_calibrated + assumptions.base_year_private_saving_adjustment

    # Reserve response to import changes
    d =
        (flows[:reserve_related_financial_flow] / v[:E]) /
        (v[:MPI] * v[:M] - lag[:MPI] * lag[:M])

    # Government foreign borrowing relative to exports
    g = v[:NFDG] / (v[:XPI] * v[:X])

    # Investment function intercept (slope k1 assumed)
    k0 = (v[:IV] - k1 * (v[:GDP] - lag[:GDP])) / lag[:GDP]

    # Import demand intercept (elasticities m1, m2 assumed)
    m0 = log(v[:M]) - m1 * log(v[:GDP]) - m2 * log(v[:E] * v[:MPI] / v[:PD])

    # Money velocity
    velocity = v[:GDPN] / v[:MS]

    # Implicit interest rates on lagged debt stocks
    irdg = v[:INDG] / lag[:NDDG]
    irfg = v[:INFG] / lag[:NFDG]
    irfp = v[:INFP] / lag[:NFDP]

    return Dict{Symbol, Float64}(
        :b_calibrated => b_calibrated, :b_base => b_base,
        :d => d, :g => g,
        :k0 => k0, :k1 => k1,
        :m0 => m0, :m1 => m1, :m2 => m2,
        :v => velocity,
        :irdg => irdg, :irfg => irfg, :irfp => irfp,
    )
end

# ==============================================================================
# Builder
# ==============================================================================

function build_base_year(obs, assumptions, sam::SAM; year::Int)
    lag_year = year - 1

    current = model_level_state(obs, assumptions, year, year)
    lag = model_level_state(obs, assumptions, lag_year, year)

    # Lagged financial stocks come from the SAM's flow decomposition.
    for name in (:NDDG, :NFDG, :NFDP)
        lag[name] = sam.lag[name]
    end

    flows = sam.flows

    # Levels and prices ----------------------------------------------------------

    v = Dict{Any, Float64}(pairs(current)...)

    v[:P] = v[:GDPN] / v[:GDP]

    # Flows taken from the SAM ---------------------------------------------------

    for name in (:GT, :TG, :IVG, :NTRG, :NTRP, :FDI, :NFP, :INFG, :INFP, :INDG,
                 :CP, :CG, :IV, :IVP)
        v[name] = flows[name]
    end

    v[:C] = v[:CP] + v[:CG]

    for type in MODEL_SETS.public_investment_types
        v[(:IVGI, type)] =
            assumptions.government_investment_shares[type] *
            v[:IVG]
    end


    # Sectoral splits ------------------------------------------------------------

    sectors = MODEL_SETS.sectors

    GDP_shares = sector_shares(
        read_group(obs, SECTOR_GDP, year),
        sectors,
    )

    export_shares = sector_shares(
        observed_sector_exports(obs, year),
        sectors,
    )

    for sector in sectors
        v[(:GDPS, sector)] = GDP_shares[sector] * v[:GDP]
        v[(:XS, sector)] = export_shares[sector] * v[:X]
    end

    # Accounting identities --------------------------------------------------------

    v[:RESBAL] = v[:XPI] * v[:X] - v[:MPI] * v[:M]

    v[:NETFSY] = v[:NFP] - v[:INFG] - v[:INFP]

    v[:CURBAL] = v[:RESBAL] + v[:NETFSY] + v[:NTRG] + v[:NTRP]

    v[:GDY] =
        v[:P] * v[:GDP] +
        v[:E] * v[:NFP] +
        v[:E] * v[:NTRP] +
        v[:INDG] +
        (v[:GT] - v[:TG]) -
        v[:E] * v[:INFP]

    v[:GDS] =
        v[:P] * v[:GDP] +
        v[:E] * (v[:NFP] - v[:INFG] - v[:INFP]) +
        v[:E] * (v[:NTRP] + v[:NTRG]) -
        v[:PD] * v[:C]

    v[:BRG] =
        v[:PD] * (v[:CG] + v[:IVG]) +
        (v[:GT] - v[:TG]) +
        v[:INDG] +
        v[:E] * (v[:INFG] - v[:NTRG])

    calibrated = calibrate_parameters(v, lag, flows, assumptions)

    return BaseYearState(year, lag_year, v, lag, calibrated, sam)
end