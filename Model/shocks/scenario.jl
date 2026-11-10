# ==============================================================================
# Scenarios
#
# Each scenario contains only the assumptions that change from the baseline.
# The scenario name is written on the left-hand side.
# ==============================================================================

const SCENARIOS = (
    industrial_export_slowdown = (
        export_growth = Dict(
            :industry => Dict(
                2026 => 0.040,
                2029 => 0.090,
            ),
        ),
    ),
)

# Variables shown in the report.
# Indexed variables can be written as (:IVGI, :infrastructure).

const PLOT_VARIABLES = [
    (:XS, :industry),
    :X,
    :M,
]