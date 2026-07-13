using Pkg
using Serialization

Pkg.add("CairoMakie")
Pkg.update("SquareModels")
Pkg.status("SquareModels")

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

# scenario running, commented out uncomment when needed
println()
println("Running scenarios...")

run(
    `$(Base.julia_cmd()) --project=$(Base.active_project()) $(joinpath(@__DIR__, "shocks", "run_scenario.jl"))`,
)