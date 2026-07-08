include(joinpath(@__DIR__, "reader.jl"))
include(joinpath(@__DIR__, "assumptions.jl"))
include(joinpath(@__DIR__, "sam.jl"))
include(joinpath(@__DIR__, "base_year.jl"))
include(joinpath(@__DIR__, "projection_paths.jl"))
include(joinpath(@__DIR__, "checks.jl"))

function build_model_data(
    workbook::AbstractString;
    base_year::Int = 2024,
    horizon::Int = 5,
    run_checks::Bool = true,
)
    raw = read_inputs(workbook)
    assumptions = model_assumptions()

    sam = build_sam(
        raw,
        assumptions;
        year = base_year,
    )

    base = build_base_year(
        raw,
        assumptions,
        sam;
        year = base_year,
    )

    projection = build_projection_paths(
        base,
        assumptions;
        horizon,
    )

    run_checks && check_sam_balance(sam)
    run_checks && check_base_year(base)
    run_checks && check_projection_paths(projection; horizon)

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