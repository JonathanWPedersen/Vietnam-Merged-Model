# ==============================================================================
# Scenarios
#
# Each scenario contains only the assumptions that change from the baseline.
# The scenario name is written on the left-hand side.
# ==============================================================================

const SCENARIOS = (
    export_slowdown = (
        export_growth = Dict(
            :industry => Dict(
                2027 => -0.030,
            ),
        ),
    ),

    fdi_slowdown = (
        foreign_direct_investment_growth = Dict(
            2027 => -0.200,
        ),
    ),

    infrastructure_expansion = (
        government_investment_growth = Dict(
            :infrastructure => Dict(
                2027 => 0.150,
            ),
        ),
    ),

    combined_external_shock = (
        export_growth = Dict(
            :industry => Dict(
                2027 => -0.030,
            ),
        ),

        foreign_direct_investment_growth = Dict(
            2027 => -0.200,
        ),
    ),
)

# Variables shown in the report.
# Indexed variables can be written as (:IVGI, :infrastructure).

const PLOT_VARIABLES = [
    :GDP,
    :X,
    :M,
    :IV,
    :IVG,
    :IVP,
    :BRG,
    :R,
    :DCP,
    :NFDP,
]