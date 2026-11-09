# ==============================================================================
# Scenarios
#
# Each scenario contains only the assumptions that change from the baseline.
# The scenario name is written on the left-hand side.
# ==============================================================================

const SCENARIOS = (
    infrastructure_expansion = (
        government_investment_growth = Dict(
            :infrastructure => Dict(
                2027 => 0.150,
            ),
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