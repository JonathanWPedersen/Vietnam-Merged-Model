# ==============================================================================
# Base-year SAM construction
# ==============================================================================

const SAM_SECTORS = (:agriculture, :industry, :services)

struct SAM
    year::Int
    lag_year::Int

    real_accounts::Vector{Symbol}
    real::Matrix{Float64}

    financial_accounts::Vector{Symbol}
    financial::Matrix{Float64}

    flows::Dict{Symbol, Float64}
    stocks::Dict{Symbol, Float64}
    lag::Dict{Symbol, Float64}

    balancing_entries::Dict{Symbol, Float64}
end

# ==============================================================================
# Unit conversions
# ==============================================================================

bn_vnd_from_tn_vnd(value::Real) = 1_000 * Float64(value)

# bn USD × thousand VND/USD = bn VND after multiplying by 1,000.
bn_vnd_from_bn_usd(value::Real, exchange_rate::Real) =
    1_000 * Float64(value) * Float64(exchange_rate)

# mn USD × thousand VND/USD = bn VND.
bn_vnd_from_mn_usd(value::Real, exchange_rate::Real) =
    Float64(value) * Float64(exchange_rate)

percent_to_share(value::Real) = Float64(value) / 100

# ==============================================================================
# Assumption helpers
# ==============================================================================

function assumed_domestic_public_debt_share(
    assumptions,
    year::Int,
)
    shares = assumptions.domestic_share_of_public_debt

    haskey(shares, year) || error(
        "Missing domestic share of public debt assumption for $year.",
    )

    value = Float64(shares[year])

    isfinite(value) || error(
        "Domestic share of public debt for $year is not finite: $value",
    )

    0.0 <= value <= 1.0 || error(
        "Domestic share of public debt for $year must lie between 0 and 1, " *
        "but is $value.",
    )

    return value
end

# ==============================================================================
# Matrix helpers
# ==============================================================================

function account_indices(accounts::Vector{Symbol})
    return Dict(account => index for (index, account) in enumerate(accounts))
end

function post!(
    matrix::Matrix{Float64},
    indices::Dict{Symbol, Int},
    receiver::Symbol,
    payer::Symbol,
    value::Real,
)
    matrix[indices[receiver], indices[payer]] += Float64(value)

    return nothing
end

function sam_differences(
    matrix::Matrix{Float64},
    accounts::Vector{Symbol},
)
    return Dict(
        account => sum(matrix[index, :]) - sum(matrix[:, index])
        for (index, account) in enumerate(accounts)
    )
end

"""
Balance a SAM with transparent entries posted to `balancing_account`.

For the legacy Vietnam financial SAM, this is used only to post the small
remaining GFIN/PFIN discrepancy. It is recorded in `balancing_entries`.
"""
function balance_sam!(
    matrix::Matrix{Float64},
    accounts::Vector{Symbol};
    balancing_account::Symbol,
    atol::Real = 1e-8,
)
    indices = account_indices(accounts)
    adjustments = Dict{Symbol, Float64}()

    for account in accounts
        account == balancing_account && continue

        difference =
            sum(matrix[indices[account], :]) -
            sum(matrix[:, indices[account]])

        abs(difference) <= atol && continue

        if difference > 0
            post!(
                matrix,
                indices,
                balancing_account,
                account,
                difference,
            )
        else
            post!(
                matrix,
                indices,
                account,
                balancing_account,
                -difference,
            )
        end

        adjustments[account] = difference
    end

    return adjustments
end

# ==============================================================================
# Raw stock construction
# ==============================================================================

function build_stock_state(
    raw::RawInputs,
    assumptions,
    year::Int,
)
    E = observed_value(
        raw,
        "IMF financial data",
        "Exchange rate, period average",
        year,
    )

    GDPN = observed_value(
        raw,
        "GSO national accounts — nominal expenditure",
        "Nominal GDP",
        year,
    )

    M2 = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "Broad money / M2",
        year,
    ))

    NFA = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "Net foreign assets",
        year,
    ))

    DCG = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "Credit to government",
        year,
    ))

    credit_state_enterprises = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "Credit to state enterprises",
        year,
    ))

    credit_others = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "Credit to others",
        year,
    ))

    other_net_borrowing = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "Other net borrowing",
        year,
    ))

    DCP =
        credit_state_enterprises +
        credit_others +
        other_net_borrowing

    DC = DCG + DCP

    public_debt_ratio = percent_to_share(observed_value(
        raw,
        "Debt data",
        "Public debt stock",
        year,
    ))

    external_debt_ratio = percent_to_share(observed_value(
        raw,
        "Debt data",
        "Total external debt",
        year,
    ))

    domestic_public_debt_share =
        assumed_domestic_public_debt_share(
            assumptions,
            year,
        )

    public_debt = public_debt_ratio * GDPN
    domestic_public_debt = domestic_public_debt_share * public_debt

    NDDG = domestic_public_debt - DCG
    NFDG = (public_debt - domestic_public_debt) / E
    NFDP = external_debt_ratio * GDPN / E - NFDG

    return Dict{Symbol, Float64}(
        :E => E,
        :GDPN => GDPN,

        :M2 => M2,
        :MD => M2,
        :MS => M2,

        :NFA => NFA,
        :R => NFA / E,

        :DCG => DCG,
        :DCP => DCP,
        :DC => DC,

        :NDDG => NDDG,
        :NFDG => NFDG,
        :NFDP => NFDP,

        :public_debt => public_debt,
        :total_external_debt => external_debt_ratio * GDPN,
    )
end

# ==============================================================================
# Sectoral export composition
# ==============================================================================

function observed_sector_exports(
    raw::RawInputs,
    year::Int,
)
    group = "GSO trade — goods exports by activity"

    agriculture = observed_value(
        raw,
        group,
        "Goods exports — Agriculture, Forestry and Fishing",
        year,
    )

    industry = sum((
        observed_value(
            raw,
            group,
            "Goods exports — Mining and quarrying",
            year,
        ),
        observed_value(
            raw,
            group,
            "Goods exports — Manufacturing",
            year,
        ),
        observed_value(
            raw,
            group,
            "Goods exports — Electricity, gas, steam and air conditioning supply",
            year,
        ),
        observed_value(
            raw,
            group,
            "Goods exports — Water supply, sewerage, waste management and remediation activities",
            year,
        ),
        observed_value(
            raw,
            group,
            "Goods exports — Other commodities, n.e.s",
            year,
        ),
    ))

    services = sum((
        observed_value(
            raw,
            group,
            "Goods exports — Transportation and storage",
            year,
        ),
        observed_value(
            raw,
            group,
            "Goods exports — Information and communication",
            year,
        ),
        observed_value(
            raw,
            group,
            "Goods exports — Professional, scientific and technical activities",
            year,
        ),
        observed_value(
            raw,
            group,
            "Goods exports — Arts, entertainment and recreation",
            year,
        ),
        observed_value(
            raw,
            "GSO trade — services exports",
            "Services exports, balance-of-payments basis",
            year,
        ),
    ))

    return Dict(
        :agriculture => agriculture,
        :industry => industry,
        :services => services,
    )
end

function aggregate_external_trade(
    raw::RawInputs,
    year::Int,
)
    goods_exports = observed_value(
        raw,
        "IMF external accounts — goods trade",
        "Goods exports",
        year,
    )

    service_exports = observed_value(
        raw,
        "IMF external accounts — non-factor services",
        "Non-factor services exports",
        year,
    )

    goods_imports = observed_value(
        raw,
        "IMF external accounts — goods trade",
        "Goods imports",
        year,
    )

    service_imports = observed_value(
        raw,
        "IMF external accounts — non-factor services",
        "Non-factor services imports",
        year,
    )

    return (
        exports_bn_usd = goods_exports + service_exports,
        imports_bn_usd = goods_imports + service_imports,
    )
end

# ==============================================================================
# SAM builder
# ==============================================================================

function build_sam(
    raw::RawInputs,
    assumptions;
    year::Int,
)
    lag_year = year - 1

    stocks = build_stock_state(
        raw,
        assumptions,
        year,
    )

    observed_lag = build_stock_state(
        raw,
        assumptions,
        lag_year,
    )

    E = stocks[:E]
    E_lag = observed_lag[:E]

    # --------------------------------------------------------------------------
    # National accounts
    # --------------------------------------------------------------------------

    GDP = stocks[:GDPN]

    CP = observed_value(
        raw,
        "GSO national accounts — nominal expenditure",
        "Household consumption",
        year,
    )

    CG = observed_value(
        raw,
        "GSO national accounts — nominal expenditure",
        "Public consumption",
        year,
    )

    gross_capital_formation = observed_value(
        raw,
        "GSO national accounts — nominal expenditure",
        "Gross capital formation",
        year,
    )

    GSO_trade_balance = observed_value(
        raw,
        "GSO national accounts — nominal expenditure",
        "Trade balance (goods and services)",
        year,
    )

    # --------------------------------------------------------------------------
    # External account
    # --------------------------------------------------------------------------

    trade = aggregate_external_trade(raw, year)

    X = 1_000 * trade.exports_bn_usd
    M = 1_000 * trade.imports_bn_usd

    exports_vnd = E * X
    imports_vnd = E * M

    investment_reconciliation =
        GSO_trade_balance - (exports_vnd - imports_vnd)

    NTRG = 1_000 * observed_value(
        raw,
        "IMF external and fiscal data",
        "Government transfers from abroad",
        year,
    )

    NTRP = 1_000 * observed_value(
        raw,
        "IMF external and fiscal data",
        "Private transfers from abroad",
        year,
    )

    foreign_income = observed_value(
        raw,
        "IMF external and fiscal data",
        "Foreign investment income",
        year,
    )

    foreign_payments = observed_value(
        raw,
        "IMF external and fiscal data",
        "Foreign investment payments",
        year,
    )

    foreign_interest_total = observed_value(
        raw,
        "IMF external and fiscal data",
        "Foreign interest payments, total",
        year,
    )

    NFP = 1_000 * (
        foreign_income -
        foreign_payments +
        foreign_interest_total
    )

    INFG = observed_value(
        raw,
        "Foreign interest-payment detail",
        "Government foreign interest payments",
        year,
    )

    INFP = observed_value(
        raw,
        "Foreign interest-payment detail",
        "Private foreign interest payments",
        year,
    )

    FDI = 1_000 * observed_value(
        raw,
        "IMF external and fiscal data",
        "Foreign direct investment",
        year,
    )

    CURBAL = 1_000 * observed_value(
        raw,
        "IMF external and fiscal data",
        "Current account balance",
        year,
    )

    # --------------------------------------------------------------------------
    # Fiscal account
    # --------------------------------------------------------------------------

    IMF_GDP = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "IMF nominal GDP",
        year,
    ))

    government_revenue_ratio = percent_to_share(observed_value(
        raw,
        "IMF external and fiscal data",
        "Government revenue excluding grants",
        year,
    ))

    public_current_expenditure_ratio = percent_to_share(observed_value(
        raw,
        "IMF external and fiscal data",
        "Public current expenditure excluding interest",
        year,
    ))

    public_interest_ratio = percent_to_share(observed_value(
        raw,
        "IMF external and fiscal data",
        "Public interest payments",
        year,
    ))

    public_investment_ratio = percent_to_share(observed_value(
        raw,
        "IMF external and fiscal data",
        "Public investment",
        year,
    ))

    public_net_onlending_ratio = percent_to_share(observed_value(
        raw,
        "IMF external and fiscal data",
        "Public net onlending",
        year,
    ))

    TG = government_revenue_ratio * IMF_GDP

    public_current_expenditure =
        public_current_expenditure_ratio * IMF_GDP

    GT = public_current_expenditure - CG

    public_interest_payments =
        public_interest_ratio * IMF_GDP

    INDG = public_interest_payments - E * INFG

    IVG =
        public_investment_ratio * IMF_GDP +
        investment_reconciliation

    IV = gross_capital_formation + investment_reconciliation
    IVP = IV - IVG

    government_saving =
        TG +
        E * NTRG -
        CG -
        GT -
        INDG -
        E * INFG

    government_capital_balance =
        government_saving - IVG

    # --------------------------------------------------------------------------
    # Private-sector account
    # --------------------------------------------------------------------------

    private_external_income = E * (NTRP + NFP)

    private_saving =
        GDP +
        GT +
        INDG +
        private_external_income -
        CP -
        TG -
        E * INFP

    # --------------------------------------------------------------------------
    # Financial-account construction
    # --------------------------------------------------------------------------

    delta_DCG = stocks[:DCG] - observed_lag[:DCG]
    delta_DCP = stocks[:DCP] - observed_lag[:DCP]
    delta_MS = stocks[:MS] - observed_lag[:MS]

    bank_share = percent_to_share(observed_value(
        raw,
        "IMF financial data",
        "Banking-system share of government domestic debt change",
        year,
    ))

    government_domestic_debt_change = bn_vnd_from_tn_vnd(observed_value(
        raw,
        "IMF financial data",
        "Government net domestic debt change",
        year,
    ))

    banking_system_financing =
        bank_share * government_domestic_debt_change

    nonbank_public_financing =
        government_domestic_debt_change -
        banking_system_financing

    ODA_share =
        Float64(
            assumptions.oda_financed_share_of_public_net_onlending,
        )

    domestic_net_onlending =
        (1 - ODA_share) *
        public_net_onlending_ratio *
        IMF_GDP

    delta_NDDG =
        nonbank_public_financing -
        domestic_net_onlending

    NDDG_lag = stocks[:NDDG] - delta_NDDG

    capital_gain =
        (E - E_lag) * observed_lag[:R]

    reserve_related_financial_flow =
        (stocks[:NFA] - observed_lag[:NFA]) -
        capital_gain

    government_foreign_debt_change_ratio =
        Float64(
            assumptions.government_foreign_debt_change_share_of_imf_gdp,
        )

    preliminary_government_foreign_debt_change =
        government_foreign_debt_change_ratio * IMF_GDP

    government_foreign_financing_reconciliation =
        Float64(
            assumptions.government_foreign_financing_reconciliation,
        )

    delta_NFDG_vnd =
        preliminary_government_foreign_debt_change -
        government_foreign_financing_reconciliation

    delta_NFDG = delta_NFDG_vnd / E
    NFDG_lag = stocks[:NFDG] - delta_NFDG

    delta_R = stocks[:R] - observed_lag[:R]

    delta_NFDP =
        delta_R -
        CURBAL -
        delta_NFDG -
        FDI

    NFDP_lag = stocks[:NFDP] - delta_NFDP

    # --------------------------------------------------------------------------
    # Real SAM
    # --------------------------------------------------------------------------

    real_accounts = [
        :COM,
        :PRV,
        :STATE,
        :GCAP,
        :PCAP,
        :DFIN,
        :FFIN,
        :ROW,
    ]

    real_indices = account_indices(real_accounts)

    real = zeros(
        length(real_accounts),
        length(real_accounts),
    )

    post!(real, real_indices, :COM, :PRV, CP)
    post!(real, real_indices, :COM, :STATE, CG)
    post!(real, real_indices, :COM, :GCAP, IVG)
    post!(real, real_indices, :COM, :PCAP, IVP)
    post!(real, real_indices, :COM, :ROW, exports_vnd)

    post!(real, real_indices, :PRV, :COM, GDP)
    post!(real, real_indices, :PRV, :STATE, GT)
    post!(real, real_indices, :PRV, :DFIN, INDG)
    post!(real, real_indices, :PRV, :ROW, private_external_income)

    post!(real, real_indices, :STATE, :PRV, TG)
    post!(real, real_indices, :STATE, :ROW, E * NTRG)

    post!(real, real_indices, :GCAP, :STATE, government_saving)

    post!(real, real_indices, :PCAP, :PRV, private_saving)
    post!(
        real,
        real_indices,
        :PCAP,
        :GCAP,
        government_capital_balance,
    )
    post!(real, real_indices, :PCAP, :ROW, -E * CURBAL)

    post!(real, real_indices, :DFIN, :STATE, INDG)

    post!(real, real_indices, :FFIN, :PRV, E * INFP)
    post!(real, real_indices, :FFIN, :STATE, E * INFG)

    post!(real, real_indices, :ROW, :COM, imports_vnd)
    post!(real, real_indices, :ROW, :FFIN, E * (INFG + INFP))

    real_adjustments = balance_sam!(
        real,
        real_accounts;
        balancing_account = :PCAP,
    )

    # --------------------------------------------------------------------------
    # Financial SAM
    # --------------------------------------------------------------------------

    financial_accounts = [
        :DFIN,
        :FFIN,
        :FDI,
        :GFIN,
        :PFIN,
        :CAPGAIN,
        :GCAP,
        :PCAP,
    ]

    financial_indices = account_indices(financial_accounts)

    financial = zeros(
        length(financial_accounts),
        length(financial_accounts),
    )

    post!(financial, financial_indices, :DFIN, :PFIN, delta_MS)

    post!(
        financial,
        financial_indices,
        :FFIN,
        :DFIN,
        reserve_related_financial_flow,
    )

    post!(financial, financial_indices, :FFIN, :PCAP, -E * CURBAL)

    post!(financial, financial_indices, :FDI, :FFIN, E * FDI)

    post!(financial, financial_indices, :GFIN, :DFIN, delta_DCG)
    post!(
        financial,
        financial_indices,
        :GFIN,
        :FFIN,
        delta_NFDG_vnd,
    )
    post!(financial, financial_indices, :GFIN, :PFIN, delta_NDDG)
    post!(
        financial,
        financial_indices,
        :GFIN,
        :GCAP,
        government_saving,
    )

    post!(financial, financial_indices, :PFIN, :DFIN, delta_DCP)
    post!(
        financial,
        financial_indices,
        :PFIN,
        :FFIN,
        E * delta_NFDP,
    )
    post!(financial, financial_indices, :PFIN, :FDI, E * FDI)
    post!(
        financial,
        financial_indices,
        :PFIN,
        :CAPGAIN,
        capital_gain,
    )
    post!(
        financial,
        financial_indices,
        :PFIN,
        :PCAP,
        private_saving,
    )

    post!(
        financial,
        financial_indices,
        :CAPGAIN,
        :DFIN,
        capital_gain,
    )

    post!(financial, financial_indices, :GCAP, :GFIN, IVG)
    post!(
        financial,
        financial_indices,
        :GCAP,
        :PCAP,
        government_capital_balance,
    )

    post!(financial, financial_indices, :PCAP, :PFIN, IVP)

    financial_adjustments = balance_sam!(
        financial,
        financial_accounts;
        balancing_account = :PFIN,
    )

    # --------------------------------------------------------------------------
    # Output object
    # --------------------------------------------------------------------------

    flows = Dict{Symbol, Float64}(
        :CP => CP,
        :CG => CG,
        :C => CP + CG,

        :IV => IV,
        :IVG => IVG,
        :IVP => IVP,

        :GT => GT,
        :TG => TG,
        :INDG => INDG,

        :X => X,
        :M => M,

        :NTRG => NTRG,
        :NTRP => NTRP,
        :NFP => NFP,
        :INFG => INFG,
        :INFP => INFP,
        :FDI => FDI,

        :CURBAL => CURBAL,

        :government_saving => government_saving,
        :government_capital_balance => government_capital_balance,
        :private_saving => private_saving,

        :investment_reconciliation => investment_reconciliation,

        :capital_gain => capital_gain,
        :reserve_related_financial_flow =>
            reserve_related_financial_flow,

        :delta_DCG => delta_DCG,
        :delta_DCP => delta_DCP,
        :delta_MS => delta_MS,

        :delta_NDDG => delta_NDDG,
        :delta_NFDG => delta_NFDG,
        :delta_NFDP => delta_NFDP,
    )

    lag = copy(observed_lag)

    lag[:NDDG] = NDDG_lag
    lag[:NFDG] = NFDG_lag
    lag[:NFDP] = NFDP_lag

    balancing_entries = Dict{Symbol, Float64}()

    for (account, adjustment) in real_adjustments
        balancing_entries[Symbol(:real_, account)] =
            adjustment
    end

    for (account, adjustment) in financial_adjustments
        balancing_entries[Symbol(:financial_, account)] =
            adjustment
    end

    return SAM(
        year,
        lag_year,

        real_accounts,
        real,

        financial_accounts,
        financial,

        flows,
        stocks,
        lag,

        balancing_entries,
    )
end