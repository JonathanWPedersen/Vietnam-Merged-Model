using XLSX

# ==============================================================================
# Unit conversions
# ==============================================================================

bn_vnd_from_tn_vnd(x) = 1_000 * x
mn_usd_from_bn_usd(x) = 1_000 * x
percent_to_share(x) = x / 100

# ==============================================================================
# Reading the workbook
# ==============================================================================

"""
Read the "Observed Data" sheet into a Dict keyed by (source group, series, year).
Row 1 is the sheet title; row 2 holds the headers. Year columns are recognised
by their four-digit headers; all other columns (Unit, Published source, ...)
are documentation and ignored here.
"""
function read_inputs(workbook::AbstractString)
    table = XLSX.readtable(workbook, "Observed Data"; first_row = 2)

    labels = string.(table.column_labels)
    year_columns = [
        (parse(Int, label), col)
        for (col, label) in enumerate(labels) if occursin(r"^(19|20)\d{2}$", label)
    ]

    group = table.data[findfirst(==("Source group"), labels)]
    series = table.data[findfirst(==("Series"), labels)]

    observed = Dict{Tuple{String, String, Int}, Float64}()

    for row in eachindex(group)
        for (year, col) in year_columns
            value = table.data[col][row]
            value === missing && continue
            observed[(string(group[row]), string(series[row]), year)] = Float64(value)
        end
    end

    return observed
end

function observed_value(obs, group, series, year)
    haskey(obs, (group, series, year)) ||
        error("Missing observation: $group / $series / $year")
    return obs[(group, series, year)]
end

# ==============================================================================
# Series tables: model name => (workbook series, unit conversion)
#
# The source-group string is stated once per table. Adding a series to the
# model means adding one line here.
# ==============================================================================

const NATIONAL_ACCOUNTS = "GSO national accounts — nominal expenditure" => [
    :GDPN          => ("Nominal GDP",                        identity),
    :CP            => ("Household consumption",              identity),
    :CG            => ("Public consumption",                 identity),
    :IV_total      => ("Gross capital formation",            identity),
    :trade_balance => ("Trade balance (goods and services)", identity),
]

const REAL_ACCOUNTS = "GSO national accounts — real expenditure" => [
    :GDP_real => ("Real GDP", identity),
]

const SECTOR_GDP = "GSO national accounts — real sector GDP" => [
    :agriculture => ("Agriculture GDP", identity),
    :industry    => ("Industry GDP",    identity),
    :services    => ("Services GDP",    identity),
]

const MONETARY = "IMF financial data" => [
    :E                    => ("Exchange rate, period average",    identity),
    :IMF_GDP              => ("IMF nominal GDP",                  bn_vnd_from_tn_vnd),
    :M2                   => ("Broad money / M2",                 bn_vnd_from_tn_vnd),
    :NFA                  => ("Net foreign assets",               bn_vnd_from_tn_vnd),
    :DCG                  => ("Credit to government",             bn_vnd_from_tn_vnd),
    :credit_soe           => ("Credit to state enterprises",      bn_vnd_from_tn_vnd),
    :credit_other         => ("Credit to others",                 bn_vnd_from_tn_vnd),
    :other_net_borrowing  => ("Other net borrowing",              bn_vnd_from_tn_vnd),
    :domestic_debt_change => ("Government net domestic debt change", bn_vnd_from_tn_vnd),
    :bank_share => ("Banking-system share of government domestic debt change", percent_to_share),
]

const DEBT_RATIOS = "Debt data" => [
    :public_debt_ratio   => ("Public debt stock",     percent_to_share),
    :external_debt_ratio => ("Total external debt",   percent_to_share),
]

# Model USD unit is mn USD; the workbook reports these in bn USD.
const EXTERNAL_FLOWS = "IMF external and fiscal data" => [
    :NTRG             => ("Government transfers from abroad",  mn_usd_from_bn_usd),
    :NTRP             => ("Private transfers from abroad",     mn_usd_from_bn_usd),
    :foreign_income   => ("Foreign investment income",         mn_usd_from_bn_usd),
    :foreign_payments => ("Foreign investment payments",       mn_usd_from_bn_usd),
    :foreign_interest => ("Foreign interest payments, total",  mn_usd_from_bn_usd),
    :FDI              => ("Foreign direct investment",         mn_usd_from_bn_usd),
    :CURBAL           => ("Current account balance",           mn_usd_from_bn_usd),
]

const FISCAL_RATIOS = "IMF external and fiscal data" => [
    :revenue_ratio             => ("Government revenue excluding grants",          percent_to_share),
    :current_expenditure_ratio => ("Public current expenditure excluding interest", percent_to_share),
    :interest_ratio            => ("Public interest payments",                     percent_to_share),
    :investment_ratio          => ("Public investment",                            percent_to_share),
    :net_onlending_ratio       => ("Public net onlending",                         percent_to_share),
]

# Already in mn USD in the workbook.
const INTEREST_DETAIL = "Foreign interest-payment detail" => [
    :INFG => ("Government foreign interest payments", identity),
    :INFP => ("Private foreign interest payments",    identity),
]

const GOODS_TRADE = "IMF external accounts — goods trade" => [
    :goods_exports => ("Goods exports", identity),
    :goods_imports => ("Goods imports", identity),
]

const SERVICES_TRADE = "IMF external accounts — non-factor services" => [
    :services_exports => ("Non-factor services exports", identity),
    :services_imports => ("Non-factor services imports", identity),
]

const SECTOR_EXPORT_GROUP = "GSO trade — goods exports by activity"

const SECTOR_EXPORT_SERIES = Dict(
    :agriculture => [
        "Goods exports — Agriculture, Forestry and Fishing",
    ],
    :industry => [
        "Goods exports — Mining and quarrying",
        "Goods exports — Manufacturing",
        "Goods exports — Electricity, gas, steam and air conditioning supply",
        "Goods exports — Water supply, sewerage, waste management and remediation activities",
        "Goods exports — Other commodities, n.e.s",
    ],
    :services => [
        "Goods exports — Transportation and storage",
        "Goods exports — Information and communication",
        "Goods exports — Professional, scientific and technical activities",
        "Goods exports — Arts, entertainment and recreation",
    ],
)

# ==============================================================================
# Group readers
# ==============================================================================

"""
Read every series in a table for one year. Returns a NamedTuple, so
`read_group(obs, MONETARY, 2025).M2` is the M2 stock in model units.
"""
function read_group(obs, table, year)
    group, entries = table
    return (;
        (name => scale(observed_value(obs, group, series, year))
         for (name, (series, scale)) in entries)...,
    )
end

"Aggregate goods + non-factor services trade, in mn USD."
function aggregate_external_trade(obs, year)
    g = read_group(obs, GOODS_TRADE, year)
    s = read_group(obs, SERVICES_TRADE, year)

    return (
        exports = 1_000 * (g.goods_exports + s.services_exports),
        imports = 1_000 * (g.goods_imports + s.services_imports),
    )
end

"Exports by model sector, mn USD. Services include BOP-basis services exports."
function observed_sector_exports(obs, year)
    goods(sector) = sum(
        observed_value(obs, SECTOR_EXPORT_GROUP, series, year)
        for series in SECTOR_EXPORT_SERIES[sector]
    )

    return Dict(
        :agriculture => goods(:agriculture),
        :industry    => goods(:industry),
        :services    => goods(:services) + observed_value(
            obs,
            "GSO trade — services exports",
            "Services exports, balance-of-payments basis",
            year,
        ),
    )
end