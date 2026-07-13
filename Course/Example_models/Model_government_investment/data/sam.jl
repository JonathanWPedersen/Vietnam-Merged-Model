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
# Matrix helpers
# ==============================================================================

account_indices(accounts) =
    Dict(account => index for (index, account) in enumerate(accounts))

function post!(matrix, indices, receiver::Symbol, payer::Symbol, value)
    matrix[indices[receiver], indices[payer]] += value
    return nothing
end

"""
Balance a SAM by posting each account's row/column difference against
`balancing_account`. Returns the adjustments, which are recorded in the
SAM's `balancing_entries` so nothing is hidden.
"""
function balance_sam!(matrix, accounts; balancing_account::Symbol, atol = 1e-8)
    indices = account_indices(accounts)
    adjustments = Dict{Symbol, Float64}()

    for account in accounts
        account == balancing_account && continue

        difference = sum(matrix[indices[account], :]) - sum(matrix[:, indices[account]])
        abs(difference) <= atol && continue

        if difference > 0
            post!(matrix, indices, balancing_account, account, difference)
        else
            post!(matrix, indices, account, balancing_account, -difference)
        end

        adjustments[account] = difference
    end

    return adjustments
end

# ==============================================================================
# Stocks
# ==============================================================================

"""
All observed stocks for one year (in model units), plus the derived
government/private, domestic/foreign debt decomposition.
"""
function build_stock_state(obs, assumptions, year)
    m = read_group(obs, MONETARY, year)
    debt = read_group(obs, DEBT_RATIOS, year)
    GDPN = read_group(obs, NATIONAL_ACCOUNTS, year).GDPN

    DCP = m.credit_soe + m.credit_other + m.other_net_borrowing

    share = assumptions.domestic_share_of_public_debt[year]
    public_debt = debt.public_debt_ratio * GDPN
    domestic_public_debt = share * public_debt

    NDDG = domestic_public_debt - m.DCG
    NFDG = (public_debt - domestic_public_debt) / m.E
    NFDP = debt.external_debt_ratio * GDPN / m.E - NFDG

    return Dict{Symbol, Float64}(
        pairs(m)...,
        pairs(debt)...,

        :GDPN => GDPN,
        :MD => m.M2,
        :MS => m.M2,
        :R => m.NFA / m.E,

        :DCP => DCP,
        :DC => m.DCG + DCP,

        :NDDG => NDDG,
        :NFDG => NFDG,
        :NFDP => NFDP,

        :public_debt => public_debt,
        :total_external_debt => debt.external_debt_ratio * GDPN,
    )
end

# ==============================================================================
# Flows
# ==============================================================================

function sam_flows(obs, assumptions, stocks, lag, year)
    E, E_lag = stocks[:E], lag[:E]
    GDP = stocks[:GDPN]
    IMF_GDP = stocks[:IMF_GDP]

    na = read_group(obs, NATIONAL_ACCOUNTS, year)
    ext = read_group(obs, EXTERNAL_FLOWS, year)
    fis = read_group(obs, FISCAL_RATIOS, year)
    int = read_group(obs, INTEREST_DETAIL, year)

    # External account ---------------------------------------------------------

    trade = aggregate_external_trade(obs, year)
    X, M = trade.exports, trade.imports
    exports_vnd, imports_vnd = E * X, E * M

    # GSO and IMF trade concepts differ; the wedge is absorbed in investment.
    investment_reconciliation = na.trade_balance - (exports_vnd - imports_vnd)

    NFP = ext.foreign_income - ext.foreign_payments + ext.foreign_interest

    # Fiscal account -----------------------------------------------------------

    TG = fis.revenue_ratio * IMF_GDP
    GT = fis.current_expenditure_ratio * IMF_GDP - na.CG
    INDG = fis.interest_ratio * IMF_GDP - E * int.INFG
    IVG = fis.investment_ratio * IMF_GDP + investment_reconciliation

    IV = na.IV_total + investment_reconciliation
    IVP = IV - IVG

    government_saving = TG + E * ext.NTRG - na.CG - GT - INDG - E * int.INFG
    government_capital_balance = government_saving - IVG

    # Private sector -----------------------------------------------------------

    private_external_income = E * (ext.NTRP + NFP)

    private_saving =
        GDP + GT + INDG + private_external_income - na.CP - TG - E * int.INFP

    # Financial flows ------------------------------------------------------------

    delta_DCG = stocks[:DCG] - lag[:DCG]
    delta_DCP = stocks[:DCP] - lag[:DCP]
    delta_MS = stocks[:MS] - lag[:MS]

    banking_system_financing = stocks[:bank_share] * stocks[:domestic_debt_change]
    nonbank_public_financing = stocks[:domestic_debt_change] - banking_system_financing

    domestic_net_onlending =
        (1 - assumptions.oda_financed_share_of_public_net_onlending) *
        fis.net_onlending_ratio * IMF_GDP

    delta_NDDG = nonbank_public_financing - domestic_net_onlending

    capital_gain = (E - E_lag) * lag[:R]
    reserve_related_financial_flow = (stocks[:NFA] - lag[:NFA]) - capital_gain

    delta_NFDG_vnd =
        assumptions.government_foreign_debt_change_share_of_imf_gdp * IMF_GDP -
        assumptions.government_foreign_financing_reconciliation
    delta_NFDG = delta_NFDG_vnd / E

    delta_R = stocks[:R] - lag[:R]
    delta_NFDP = delta_R - ext.CURBAL - delta_NFDG - ext.FDI

    return (;
        GDP, E, E_lag,
        CP = na.CP, CG = na.CG,
        IV, IVG, IVP,
        GT, TG, INDG,
        X, M, exports_vnd, imports_vnd,
        NTRG = ext.NTRG, NTRP = ext.NTRP, NFP,
        INFG = int.INFG, INFP = int.INFP,
        FDI = ext.FDI, CURBAL = ext.CURBAL,
        government_saving, government_capital_balance,
        private_saving, private_external_income,
        investment_reconciliation,
        capital_gain, reserve_related_financial_flow,
        delta_DCG, delta_DCP, delta_MS,
        delta_NDDG, delta_NFDG, delta_NFDG_vnd, delta_NFDP,
    )
end

# ==============================================================================
# Posting
# ==============================================================================

function post_real_sam(f)
    accounts = [:COM, :PRV, :STATE, :GCAP, :PCAP, :DFIN, :FFIN, :ROW]
    i = account_indices(accounts)
    S = zeros(length(accounts), length(accounts))
    E = f.E

    post!(S, i, :COM, :PRV, f.CP)
    post!(S, i, :COM, :STATE, f.CG)
    post!(S, i, :COM, :GCAP, f.IVG)
    post!(S, i, :COM, :PCAP, f.IVP)
    post!(S, i, :COM, :ROW, f.exports_vnd)

    post!(S, i, :PRV, :COM, f.GDP)
    post!(S, i, :PRV, :STATE, f.GT)
    post!(S, i, :PRV, :DFIN, f.INDG)
    post!(S, i, :PRV, :ROW, f.private_external_income)

    post!(S, i, :STATE, :PRV, f.TG)
    post!(S, i, :STATE, :ROW, E * f.NTRG)

    post!(S, i, :GCAP, :STATE, f.government_saving)

    post!(S, i, :PCAP, :PRV, f.private_saving)
    post!(S, i, :PCAP, :GCAP, f.government_capital_balance)
    post!(S, i, :PCAP, :ROW, -E * f.CURBAL)

    post!(S, i, :DFIN, :STATE, f.INDG)

    post!(S, i, :FFIN, :PRV, E * f.INFP)
    post!(S, i, :FFIN, :STATE, E * f.INFG)

    post!(S, i, :ROW, :COM, f.imports_vnd)
    post!(S, i, :ROW, :FFIN, E * (f.INFG + f.INFP))

    adjustments = balance_sam!(S, accounts; balancing_account = :PCAP)

    return accounts, S, adjustments
end

function post_financial_sam(f)
    accounts = [:DFIN, :FFIN, :FDI, :GFIN, :PFIN, :CAPGAIN, :GCAP, :PCAP]
    i = account_indices(accounts)
    S = zeros(length(accounts), length(accounts))
    E = f.E

    post!(S, i, :DFIN, :PFIN, f.delta_MS)

    post!(S, i, :FFIN, :DFIN, f.reserve_related_financial_flow)
    post!(S, i, :FFIN, :PCAP, -E * f.CURBAL)

    post!(S, i, :FDI, :FFIN, E * f.FDI)

    post!(S, i, :GFIN, :DFIN, f.delta_DCG)
    post!(S, i, :GFIN, :FFIN, f.delta_NFDG_vnd)
    post!(S, i, :GFIN, :PFIN, f.delta_NDDG)
    post!(S, i, :GFIN, :GCAP, f.government_saving)

    post!(S, i, :PFIN, :DFIN, f.delta_DCP)
    post!(S, i, :PFIN, :FFIN, E * f.delta_NFDP)
    post!(S, i, :PFIN, :FDI, E * f.FDI)
    post!(S, i, :PFIN, :CAPGAIN, f.capital_gain)
    post!(S, i, :PFIN, :PCAP, f.private_saving)

    post!(S, i, :CAPGAIN, :DFIN, f.capital_gain)

    post!(S, i, :GCAP, :GFIN, f.IVG)
    post!(S, i, :GCAP, :PCAP, f.government_capital_balance)

    post!(S, i, :PCAP, :PFIN, f.IVP)

    adjustments = balance_sam!(S, accounts; balancing_account = :PFIN)

    return accounts, S, adjustments
end

# ==============================================================================
# Builder
# ==============================================================================

function build_sam(obs, assumptions; year::Int)
    lag_year = year - 1

    stocks = build_stock_state(obs, assumptions, year)
    lag = build_stock_state(obs, assumptions, lag_year)

    f = sam_flows(obs, assumptions, stocks, lag, year)

    real_accounts, real, real_adjustments = post_real_sam(f)
    financial_accounts, financial, financial_adjustments = post_financial_sam(f)

    # Lagged debt stocks implied by the flow decomposition (these replace the
    # observed lag values, which are on a different accounting basis).
    lag[:NDDG] = stocks[:NDDG] - f.delta_NDDG
    lag[:NFDG] = stocks[:NFDG] - f.delta_NFDG
    lag[:NFDP] = stocks[:NFDP] - f.delta_NFDP

    flows = Dict{Symbol, Float64}(
        :CP => f.CP, :CG => f.CG, :C => f.CP + f.CG,
        :IV => f.IV, :IVG => f.IVG, :IVP => f.IVP,
        :GT => f.GT, :TG => f.TG, :INDG => f.INDG,
        :X => f.X, :M => f.M,
        :NTRG => f.NTRG, :NTRP => f.NTRP, :NFP => f.NFP,
        :INFG => f.INFG, :INFP => f.INFP, :FDI => f.FDI,
        :CURBAL => f.CURBAL,

        :government_saving => f.government_saving,
        :government_capital_balance => f.government_capital_balance,
        :private_saving => f.private_saving,

        :investment_reconciliation => f.investment_reconciliation,
        :capital_gain => f.capital_gain,
        :reserve_related_financial_flow => f.reserve_related_financial_flow,

        :delta_DCG => f.delta_DCG, :delta_DCP => f.delta_DCP, :delta_MS => f.delta_MS,
        :delta_NDDG => f.delta_NDDG, :delta_NFDG => f.delta_NFDG, :delta_NFDP => f.delta_NFDP,
    )

    balancing_entries = Dict{Symbol, Float64}()

    for (account, adjustment) in real_adjustments
        balancing_entries[Symbol(:real_, account)] = adjustment
    end

    for (account, adjustment) in financial_adjustments
        balancing_entries[Symbol(:financial_, account)] = adjustment
    end

    return SAM(
        year, lag_year,
        real_accounts, real,
        financial_accounts, financial,
        flows, stocks, lag,
        balancing_entries,
    )
end