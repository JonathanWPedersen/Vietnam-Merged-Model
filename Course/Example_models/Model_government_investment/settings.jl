# ==============================================================================
# Project settings
# ==============================================================================

root = @__DIR__

# ==============================================================================
# Time configuration
# ==============================================================================

base_year = 2024
horizon = 5

# Model time indices:
base_period = 0
first_projection_period = 1
projection_periods = first_projection_period:horizon

# ==============================================================================
# Files
# ==============================================================================

workbook = joinpath(
    root,
    "Data",
    "vietnam_model_raw_inputs.xlsx",
)

model_data_file = joinpath(
    root,
    "Data",
    "Output",
    "model_data.jls",
)

solution_file = joinpath(
    root,
    "Merged_model",
    "Output",
    "solution.jls",
)

html_report_file = joinpath(
    root,
    "Merged_model",
    "Output",
    "simulation_report.html",
)