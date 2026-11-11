using Pkg
using Serialization

Pkg.instantiate()

Pkg.activate(@__DIR__; io = devnull)

include(joinpath(@__DIR__, "settings.jl"))

println("Building model data...")
include(joinpath(@__DIR__, "Data", "data.jl"))

model_data = build_model_data(
    workbook;
    base_year = base_year,
    horizon = horizon,
)

mkpath(dirname(model_data_file))
serialize(model_data_file, model_data)

println()
println("Running model...")
include(joinpath(@__DIR__, "Merged_model", "run_model.jl"))

println()
println("Full model pipeline completed.")

# Change to true when scenarios should run.
should_scenarios_run = true

if should_scenarios_run
    println()
    println("Running scenarios...")

    run(
        `$(Base.julia_cmd()) --project=$project_root $(joinpath(project_root, "shocks", "run_scenario.jl"))`,
    )
end