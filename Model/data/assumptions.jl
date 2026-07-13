function model_assumptions()
    return (
        # Annual real growth
        gdp_growth = Dict(
            :agriculture => 0.081,
            :industry => 0.100,
            :services => 0.102,
        ),

        export_growth = Dict(
            :agriculture => 0.074,
            :industry => 0.089,
            :services => 0.107,
        ),

        # Prices and exchange rate
        exchange_rate_growth = 0.010,
        domestic_price_growth = 0.030,

        # Fiscal and external growth
        government_revenue_growth = 0.050,
        government_domestic_debt_growth = 0.050,

        government_investment_growth = Dict(
            :infrastructure => 0.050,
            :education => 0.050,
            :health => 0.050,
        ),

        government_investment_shares = Dict(
            :infrastructure => 0.60,
            :education => 0.20,
            :health => 0.20,
        ),


        net_factor_payments_growth = 0.050,
        government_transfers_growth = 0.0,
        private_transfers_growth = 0.0,
        foreign_direct_investment_growth = 0.050,

        # Interest-rate adjustments (added to base-year calibrated rates)
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
            2025 => 0.720,
        ),

        oda_financed_share_of_public_net_onlending = 0.0,

        government_foreign_debt_change_share_of_imf_gdp = -0.007,
        government_foreign_financing_reconciliation = 91_389.0,
    )
end