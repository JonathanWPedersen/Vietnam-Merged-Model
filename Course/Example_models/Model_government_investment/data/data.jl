include(joinpath(@__DIR__, "..", "sets.jl"))
include(joinpath(@__DIR__, "reader.jl"))
include(joinpath(@__DIR__, "assumptions.jl"))
include(joinpath(@__DIR__, "sam.jl"))
include(joinpath(@__DIR__, "base_year.jl"))
include(joinpath(@__DIR__, "projection_paths.jl"))
include(joinpath(@__DIR__, "checks.jl"))

function build_model_data(
    workbook::AbstractString;
    base_year::Int,   # no defaults: settings.jl is the single source of truth
    horizon::Int,
    run_checks::Bool = true,
)
    obs = read_inputs(workbook)
    assumptions = model_assumptions()

    sam = build_sam(obs, assumptions; year = base_year)
    base = build_base_year(obs, assumptions, sam; year = base_year)
    projection = build_projection_paths(base, assumptions; horizon)

    run_checks && check_sam(sam)

    return (
        source_workbook = String(workbook),

        base_year,
        horizon,
        projection_years = collect((base_year + 1):(base_year + horizon)),

        initial = base.values,
        paths = projection.paths,
        growth = projection.growth,
        parameters = projection.parameters,

        assumptions,
        sam,
        base,
    )
end