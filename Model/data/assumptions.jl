# ==============================================================================
# Scenario assumptions
# ==============================================================================

function model_assumptions()
    return (
        # Annual real growth
        agriculture_gdp_growth = 0.081,
        industry_gdp_growth = 0.100,
        services_gdp_growth = 0.102,

        agriculture_export_growth = 0.074,
        industry_export_growth = 0.089,
        services_export_growth = 0.107,

        # Prices and exchange rate
        exchange_rate_growth = 0.010,
        domestic_price_growth = 0.030,

        # Fiscal and external growth
        government_revenue_growth = 0.050,
        government_investment_growth = 0.050,
        government_domestic_debt_growth = 0.050,

        net_factor_payments_growth = 0.050,
        government_transfers_growth = 0.0,
        private_transfers_growth = 0.0,
        foreign_direct_investment_growth = 0.050,

        # Interest-rate adjustments
        government_domestic_rate_adjustment = 0.0,
        government_foreign_rate_adjustment = 0.0,
        private_foreign_rate_adjustment = 0.0,

        # Behavioural parameters
        reserve_change_import_change_response = 5 / 12,
        investment_growth_coefficient = 2.5,
        import_gdp_elasticity = 1.2,
        import_real_exchange_rate_elasticity = -1.0,

        # Base-year calibration
        base_year_domestic_price_index = 1.0,
        base_year_import_price_index = 1.0,
        base_year_export_price_index = 1.0,
        base_year_private_saving_adjustment = 0.005,

        domestic_share_of_public_debt = Dict(
            2021 => 0.700,
            2022 => 0.705,
            2023 => 0.710,
            2024 => 0.715,
        ),

        oda_financed_share_of_public_net_onlending = 0.0,

        government_foreign_debt_change_share_of_imf_gdp = -0.007,
        government_foreign_financing_reconciliation = 91_389.0,
    )
end