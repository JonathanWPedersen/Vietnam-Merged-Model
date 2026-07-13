using Pkg

project_root =
    normpath(
        joinpath(@__DIR__, ".."),
    )

Pkg.activate(
    project_root;
    io = devnull,
)

using Serialization
using CairoMakie
using SquareModels
using SquareModels.ModelPlotting: LabeledSeries, plotseries

include(
    joinpath(
        project_root,
        "settings.jl",
    ),
)

include(
    joinpath(
        project_root,
        "Data",
        "data.jl",
    ),
)

include(
    joinpath(
        project_root,
        "Merged_model",
        "model.jl",
    ),
)

include(
    joinpath(
        @__DIR__,
        "scenario.jl",
    ),
)

const SCENARIO_OUTPUT =
    joinpath(
        @__DIR__,
        "Output",
    )

const PLOT_OUTPUT =
    joinpath(
        SCENARIO_OUTPUT,
        "plots",
    )

# ==============================================================================
# Scenario assumptions
# ==============================================================================

merge_change(base, change) =
    change

# A year dictionary applied to a constant assumption automatically keeps the
# constant baseline value as the default for all other years.

function merge_change(
    base::Number,
    change::AbstractDict,
)
    return merge(
        Dict{Any, Any}(
            :default => base,
        ),
        change,
    )
end

# Merge indexed assumptions without removing unchanged components.

function merge_change(
    base::AbstractDict,
    change::AbstractDict,
)
    result =
        Dict{Any, Any}(
            pairs(base),
        )

    for (key, value) in change
        result[key] =
            haskey(base, key) ?
            merge_change(
                base[key],
                value,
            ) :
            value
    end

    return result
end

function apply_scenario(
    baseline::NamedTuple,
    changes::NamedTuple,
)
    unknown =
        setdiff(
            propertynames(changes),
            propertynames(baseline),
        )

    isempty(unknown) ||
        error(
            "Unknown assumption(s): " *
            join(
                string.(unknown),
                ", ",
            ),
        )

    return (;
        (
            name =>
                hasproperty(changes, name) ?
                merge_change(
                    getproperty(baseline, name),
                    getproperty(changes, name),
                ) :
                getproperty(baseline, name)
            for name in propertynames(baseline)
        )...,
    )
end

# ==============================================================================
# Build and solve one run
# ==============================================================================

function build_scenario_data(
    obs,
    assumptions,
)
    sam =
        build_sam(
            obs,
            assumptions;
            year = base_year,
        )

    base =
        build_base_year(
            obs,
            assumptions,
            sam;
            year = base_year,
        )

    projection =
        build_projection_paths(
            base,
            assumptions;
            horizon,
        )

    check_sam(sam)

    return (
        source_workbook = String(workbook),

        base_year,
        horizon,

        projection_years =
            collect(
                (base_year + 1):
                (base_year + horizon),
            ),

        initial = base.values,
        paths = projection.paths,
        growth = projection.growth,
        parameters = projection.parameters,

        assumptions,
        sam,
        base,
    )
end

function solve_scenario(
    obs,
    assumptions,
)
    data =
        build_scenario_data(
            obs,
            assumptions,
        )

    db, vars, blocks =
        VietnamMergedModel.build_square_model(
            data.base_year,
            data.horizon,
        )

    VietnamMergedModel.set_data!(
        db,
        vars,
        data,
    )

    solution =
        solve(
            blocks.full_model,
            db;
            replace_nothing = 1.0,
        )

    outputs =
        VietnamMergedModel.extract_outputs(
            solution,
            vars,
            data.projection_years,
        )

    return (;
        data,
        vars,
        solution,
        outputs,
    )
end

# ==============================================================================
# Save results
# ==============================================================================

function save_scenario(
    name::Symbol,
    changes,
    run,
)
    folder =
        joinpath(
            SCENARIO_OUTPUT,
            String(name),
        )

    mkpath(folder)

    result = (
        name,
        changes,

        base_year = run.data.base_year,
        horizon = run.data.horizon,
        projection_years =
            run.data.projection_years,

        initial = run.data.initial,
        paths = run.data.paths,
        growth = run.data.growth,
        parameters = run.data.parameters,

        outputs = run.outputs,
    )

    serialize(
        joinpath(
            folder,
            "result.jls",
        ),
        result,
    )

    return result
end

# ==============================================================================
# Values and labels
# ==============================================================================

function scenario_years(run)
    return collect(
        run.data.base_year:
        (
            run.data.base_year +
            run.data.horizon
        ),
    )
end

function scenario_value(
    run,
    key,
    year,
)
    reference =
        VietnamMergedModel.model_ref(
            run.vars,
            key,
            year,
        )

    return Float64(
        run.solution[reference],
    )
end

function scenario_series(
    run,
    key,
)
    return Float64[
        scenario_value(
            run,
            key,
            year,
        )
        for year in scenario_years(run)
    ]
end

scenario_label(name::Symbol) =
    name == :baseline ?
    "Baseline" :
    titlecase(
        replace(
            String(name),
            "_" => " ",
        ),
    )

variable_label(key::Symbol) =
    String(key)

variable_label(key::Tuple) =
    join(
        String.(key),
        " – ",
    )

variable_filename(key::Symbol) =
    String(key)

variable_filename(key::Tuple) =
    join(
        String.(key),
        "_",
    )

function percent_deviation(
    scenario,
    baseline,
)
    return Float64[
        iszero(base) ?
        NaN :
        100 * (
            value / base - 1
        )
        for (value, base) in
            zip(
                scenario,
                baseline,
            )
    ]
end

# ==============================================================================
# SquareModels plots
# ==============================================================================

function figure_only(result)
    return result isa Tuple ?
           first(result) :
           result
end

function create_plots(
    runs,
)
    mkpath(PLOT_OUTPUT)

    plot_files = []

    baseline =
        last(
            first(runs),
        )

    years =
        scenario_years(
            baseline,
        )

    for key in PLOT_VARIABLES
        levels =
            LabeledSeries[
                LabeledSeries(
                    years,
                    scenario_series(
                        run,
                        key,
                    ),
                    scenario_label(name),
                )
                for (name, run) in runs
            ]

        level_plot =
            plotseries(
                levels;
                title =
                    variable_label(key),
                xlabel = "Year",
                ylabel = "Level",
                legend = (
                    position = :rb,
                ),
            )

        stem =
            variable_filename(key)

        level_file =
            joinpath(
                PLOT_OUTPUT,
                "$(stem)_levels.png",
            )

        CairoMakie.save(
            level_file,
            figure_only(level_plot),
        )

        baseline_values =
            scenario_series(
                baseline,
                key,
            )

        deviations =
            LabeledSeries[
                LabeledSeries(
                    years,
                    percent_deviation(
                        scenario_series(
                            run,
                            key,
                        ),
                        baseline_values,
                    ),
                    scenario_label(name),
                )
                for (name, run) in runs[2:end]
            ]

        deviation_plot =
            plotseries(
                deviations;
                title =
                    "$(variable_label(key)): deviation from baseline",
                xlabel = "Year",
                ylabel = "Percent",
                legend = (
                    position = :rb,
                ),
            )

        deviation_file =
            joinpath(
                PLOT_OUTPUT,
                "$(stem)_deviation.png",
            )

        CairoMakie.save(
            deviation_file,
            figure_only(deviation_plot),
        )

        push!(
            plot_files,
            (
                key = key,

                level =
                    basename(level_file),

                deviation =
                    basename(deviation_file),
            ),
        )
    end

    return plot_files
end

# ==============================================================================
# HTML report
# ==============================================================================

html_escape(value) =
    replace(
        string(value),
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&#39;",
    )

function write_scenario_report(
    plot_files,
)
    report_file =
        joinpath(
            SCENARIO_OUTPUT,
            "scenario_report.html",
        )

    open(
        report_file,
        "w",
    ) do io
        print(
            io,
            """
            <!DOCTYPE html>
            <html lang="en">

            <head>
                <meta charset="UTF-8">

                <title>
                    Vietnam Merged Model — Scenarios
                </title>

                <style>
                    body {
                        margin: 0;
                        background: #f4f7fb;
                        color: #18212f;
                        font-family: Arial, sans-serif;
                    }

                    main {
                        width: min(1500px, 100%);
                        margin: 0 auto;
                        padding: 32px 26px 56px;
                    }

                    section {
                        margin-top: 24px;
                        padding: 20px;
                        background: white;
                        border: 1px solid #d9e0e8;
                        border-radius: 8px;
                    }

                    .plots {
                        display: grid;
                        grid-template-columns:
                            repeat(
                                auto-fit,
                                minmax(480px, 1fr)
                            );
                        gap: 18px;
                    }

                    img {
                        width: 100%;
                        border: 1px solid #d9e0e8;
                    }

                    pre {
                        padding: 12px;
                        overflow-x: auto;
                        background: #f3f5f7;
                    }
                </style>
            </head>

            <body>
                <main>
                    <h1>
                        Vietnam Merged Model — Scenario Report
                    </h1>

                    <section>
                        <h2>Scenarios</h2>
            """,
        )

        for (name, changes) in pairs(SCENARIOS)
            println(
                io,
                "<h3>$(html_escape(scenario_label(name)))</h3>",
            )

            println(
                io,
                "<pre>$(html_escape(repr(changes)))</pre>",
            )
        end

        println(
            io,
            "</section>",
        )

        for plot in plot_files
            title =
                variable_label(
                    plot.key,
                )

            println(
                io,
                """
                <section>
                    <h2>$(html_escape(title))</h2>

                    <div class="plots">
                        <img
                            src="plots/$(html_escape(plot.level))"
                            alt="$(html_escape(title)) levels"
                        >

                        <img
                            src="plots/$(html_escape(plot.deviation))"
                            alt="$(html_escape(title)) deviation"
                        >
                    </div>
                </section>
                """,
            )
        end

        print(
            io,
            """
                </main>
            </body>
            </html>
            """,
        )
    end

    return report_file
end

function open_report(
    report_file,
)
    absolute_path =
        abspath(report_file)

    try
        if Sys.iswindows()
            file_url =
                "file:///" *
                replace(
                    replace(
                        absolute_path,
                        '\\' => '/',
                    ),
                    " " => "%20",
                )

            run(
                Cmd(
                    [
                        "cmd",
                        "/c",
                        "start",
                        "",
                        file_url,
                    ],
                );
                wait = false,
            )

        elseif Sys.isapple()
            run(
                `open $absolute_path`;
                wait = false,
            )

        else
            run(
                `xdg-open $absolute_path`;
                wait = false,
            )
        end

    catch err
        @warn(
            "Could not open scenario report.",
            report_file,
            exception = err,
        )
    end
end

# ==============================================================================
# Run all scenarios
# ==============================================================================

mkpath(SCENARIO_OUTPUT)

obs =
    read_inputs(workbook)

baseline_assumptions =
    model_assumptions()

println("Running baseline...")

baseline =
    solve_scenario(
        obs,
        baseline_assumptions,
    )

save_scenario(
    :baseline,
    (;),
    baseline,
)

runs =
    Pair{Symbol, Any}[
        :baseline => baseline,
    ]

for (name, changes) in pairs(SCENARIOS)
    println(
        "Running $(scenario_label(name))...",
    )

    assumptions =
        apply_scenario(
            baseline_assumptions,
            changes,
        )

    scenario =
        solve_scenario(
            obs,
            assumptions,
        )

    save_scenario(
        name,
        changes,
        scenario,
    )

    push!(
        runs,
        name => scenario,
    )
end

plot_files =
    create_plots(runs)

report_file =
    write_scenario_report(
        plot_files,
    )

open_report(report_file)

println()
println("Scenario runs completed.")
println("Report: $report_file")