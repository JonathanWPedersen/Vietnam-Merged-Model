using Pkg
using Serialization

project_root = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(project_root; io = devnull)

include(joinpath(project_root, "settings.jl"))
include(joinpath(@__DIR__, "data.jl"))

println("Building model data...")

model_data = build_model_data(
    workbook;
    base_year,
    horizon,
)

mkpath(dirname(model_data_file))
serialize(model_data_file, model_data)

println("Model data saved to:")
println(model_data_file)