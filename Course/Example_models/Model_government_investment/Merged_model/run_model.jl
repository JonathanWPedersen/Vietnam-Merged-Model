using Pkg
using Serialization
using SquareModels

project_root = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(project_root; io = devnull)

include(joinpath(project_root, "settings.jl"))
include(joinpath(@__DIR__, "model.jl"))
include(joinpath(@__DIR__, "report.jl"))

model_data = deserialize(model_data_file)

db, vars, blocks = VietnamMergedModel.build_square_model(
    model_data.base_year,
    model_data.horizon,
)

VietnamMergedModel.set_data!(db, vars, model_data)

solution = solve(
    blocks.full_model,
    db;
    replace_nothing = 1.0,
)

outputs = VietnamMergedModel.extract_outputs(
    solution,
    vars,
    model_data.projection_years,
)

results = (
    source_model_data = String(model_data_file),

    base_year = model_data.base_year,
    horizon = model_data.horizon,
    projection_years = model_data.projection_years,

    initial = model_data.initial,
    paths = model_data.paths,
    growth = model_data.growth,
    parameters = model_data.parameters,

    outputs = outputs,
)

mkpath(dirname(solution_file))
serialize(solution_file, results)

report_file = write_html_simulation_report(
    html_report_file,
    results,
)

open_html_in_browser(report_file)

println()
println("Model solved successfully.")
println("Serialized solution: $solution_file")
println("HTML report:         $report_file")