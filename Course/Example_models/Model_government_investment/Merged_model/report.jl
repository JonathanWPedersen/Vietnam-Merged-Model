using Printf

function simulation_rows()
    exogenous_rows = [
        (group = "Prices", label = "E", key = :E),
        (group = "Prices", label = "PD", key = :PD),
        (group = "Prices", label = "XPI", key = :XPI),
        (group = "Prices", label = "MPI", key = :MPI),

        (
            group = "Quantities",
            label = "AGDP (bn VND, const.)",
            key = (:GDPS, :agriculture),
        ),
        (
            group = "Quantities",
            label = "IGDP (bn VND, const.)",
            key = (:GDPS, :industry),
        ),
        (
            group = "Quantities",
            label = "SGDP (bn VND, const.)",
            key = (:GDPS, :services),
        ),

        (
            group = "Quantities",
            label = "AX (mn USD)",
            key = (:XS, :agriculture),
        ),
        (
            group = "Quantities",
            label = "IX (mn USD)",
            key = (:XS, :industry),
        ),
        (
            group = "Quantities",
            label = "SX (mn USD)",
            key = (:XS, :services),
        ),

        (
            group = "Quantities",
            label = "GT (bn VND, current)",
            key = :GT,
        ),
        (
            group = "Quantities",
            label = "TG (bn VND, current)",
            key = :TG,
        ),
        (
            group = "Quantities",
            label = "NTRG (mn USD)",
            key = :NTRG,
        ),
        (
            group = "Quantities",
            label = "NTRP (mn USD)",
            key = :NTRP,
        ),

        (
            group = "Financial",
            label = "NDDG (bn VND)",
            key = :NDDG,
        ),
        (
            group = "Financial",
            label = "IRDG (rate)",
            key = :irdg,
        ),
        (
            group = "Financial",
            label = "IRFG (rate)",
            key = :irfg,
        ),
        (
            group = "Financial",
            label = "IRFP (rate)",
            key = :irfp,
        ),
        (
            group = "Financial",
            label = "FDI (mn USD)",
            key = :FDI,
        ),
        (
            group = "Financial",
            label = "NFP (mn USD)",
            key = :NFP,
        ),
    ]

    endogenous_rows = [
        (group = "", label = "P", key = :P),

        (
            group = "Quantities",
            label = "IVG (bn VND, const.)",
            key = :IVG,
        ),
        (
            group = "Public investment",
            label = "Infrastructure investment",
            key = (:IVGI, :infrastructure),
        ),
        (
            group = "Public investment",
            label = "Education investment",
            key = (:IVGI, :education),
        ),
        (
            group = "Public investment",
            label = "Health investment",
            key = (:IVGI, :health),
        ),


        (
            group = "Quantities",
            label = "GDP (bn VND, const.)",
            key = :GDP,
        ),
        (
            group = "Quantities",
            label = "GDPN (bn VND, current)",
            key = :GDPN,
        ),
        (
            group = "Quantities",
            label = "CP (bn VND, const.)",
            key = :CP,
        ),
        (
            group = "Quantities",
            label = "CG (bn VND, const.)",
            key = :CG,
        ),
        (
            group = "Quantities",
            label = "C (bn VND, const.)",
            key = :C,
        ),
        (
            group = "Quantities",
            label = "IVP (bn VND, const.)",
            key = :IVP,
        ),
        (
            group = "Quantities",
            label = "IV (bn VND, const.)",
            key = :IV,
        ),
        (
            group = "Quantities",
            label = "X (mn USD)",
            key = :X,
        ),
        (
            group = "Quantities",
            label = "M (mn USD)",
            key = :M,
        ),
        (
            group = "Quantities",
            label = "GDY (bn VND, current)",
            key = :GDY,
        ),
        (
            group = "Quantities",
            label = "GDS (bn VND, current)",
            key = :GDS,
        ),
        (
            group = "Quantities",
            label = "RESBAL (mn USD)",
            key = :RESBAL,
        ),
        (
            group = "Quantities",
            label = "NETFSY (mn USD)",
            key = :NETFSY,
        ),
        (
            group = "Quantities",
            label = "CURBAL (mn USD)",
            key = :CURBAL,
        ),
        (
            group = "Quantities",
            label = "BRG (bn VND)",
            key = :BRG,
        ),

        (
            group = "Financial",
            label = "DCP (bn VND)",
            key = :DCP,
        ),
        (
            group = "Financial",
            label = "DCG (bn VND)",
            key = :DCG,
        ),
        (
            group = "Financial",
            label = "DC (bn VND)",
            key = :DC,
        ),
        (
            group = "Financial",
            label = "INDG (bn VND)",
            key = :INDG,
        ),
        (
            group = "Financial",
            label = "INFG (mn USD)",
            key = :INFG,
        ),
        (
            group = "Financial",
            label = "INFP (mn USD)",
            key = :INFP,
        ),
        (
            group = "Financial",
            label = "MD (bn VND)",
            key = :MD,
        ),
        (
            group = "Financial",
            label = "MS (bn VND)",
            key = :MS,
        ),
        (
            group = "Financial",
            label = "NFDG (mn USD)",
            key = :NFDG,
        ),
        (
            group = "Financial",
            label = "NFDP (mn USD)",
            key = :NFDP,
        ),
        (
            group = "Financial",
            label = "R (mn USD)",
            key = :R,
        ),
    ]

    return exogenous_rows, endogenous_rows
end

function input_value(results, key, year::Int)
    if year == results.base_year
        return get(results.initial, key, nothing)
    end

    index = year - results.base_year

    for data in (
        results.paths,
        results.growth,
        results.parameters,
    )
        haskey(data, key) && return data[key][index]
    end

    return nothing
end

function display_value(results, key, year::Int)
    if year > results.base_year && haskey(results.outputs, key)
        return get(results.outputs[key], year, nothing)
    end

    return input_value(results, key, year)
end

function format_number(value)
    if value === nothing || value === missing
        return "—"
    end

    number = Float64(value)

    isfinite(number) || return string(number)

    sign = number < 0 ? "-" : ""
    text = @sprintf("%.2f", abs(number))

    integer_part, decimal_part = split(text, ".")
    groups = String[]

    while !isempty(integer_part)
        first_index = max(1, length(integer_part) - 2)

        pushfirst!(groups, integer_part[first_index:end])

        integer_part =
            first_index == 1 ? "" : integer_part[1:(first_index - 1)]
    end

    return sign * join(groups, ".") * "," * decimal_part
end

function format_percent(value)
    value === nothing && return "—"
    value === missing && return "—"

    return @sprintf("%.1f%%", Float64(value))
end

function html_escape(value)
    return replace(
        string(value),
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&#39;",
    )
end

function write_html_table!(
    io,
    results,
    title::String,
    rows;
    percent_change::Bool = false,
)
    years = results.base_year:(results.base_year + results.horizon)
    n_columns = 1 + length(years)

    println(io, """<section class="report-section">""")
    println(io, "<h2>$(html_escape(title))</h2>")
    println(io, """<div class="table-container">""")
    println(io, "<table>")

    println(io, "<thead><tr>")
    println(io, """<th class="variable-column">Variable</th>""")

    for year in years
        println(io, "<th>$year</th>")
    end

    println(io, "</tr></thead>")
    println(io, "<tbody>")

    previous_group = nothing

    for row in rows
        if !isempty(row.group) && row.group != previous_group
            println(
                io,
                """<tr class="group-row"><th colspan="$n_columns">$(html_escape(row.group))</th></tr>""",
            )
        end

        println(io, "<tr>")
        println(
            io,
            """<th scope="row" class="variable-column">$(html_escape(row.label))</th>""",
        )

        if percent_change
            println(io, "<td>—</td>")

            for year in results.projection_years
                previous = display_value(results, row.key, year - 1)
                current = display_value(results, row.key, year)

                change =
                    previous === nothing ||
                    current === nothing ||
                    previous == 0.0 ? nothing :
                    100 * (current / previous - 1)

                println(
                    io,
                    "<td>$(html_escape(format_percent(change)))</td>",
                )
            end
        else
            for year in years
                value = display_value(results, row.key, year)

                println(
                    io,
                    "<td>$(html_escape(format_number(value)))</td>",
                )
            end
        end

        println(io, "</tr>")

        previous_group = row.group
    end

    println(io, "</tbody></table>")
    println(io, "</div></section>")

    return nothing
end

function write_html_simulation_report(
    report_file::AbstractString,
    results,
)
    exogenous_rows, endogenous_rows = simulation_rows()
    change_rows = filter(row -> row.key != :P, endogenous_rows)

    mkpath(dirname(report_file))

    open(report_file, "w") do io
        print(
            io,
            """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <meta http-equiv="Cache-Control" content="no-store">
                <title>Vietnam Merged Model — Simulation Report</title>

                <style>
                    :root {
                        --page-background: #f4f7fb;
                        --card-background: #ffffff;
                        --text: #18212f;
                        --muted-text: #5c6878;
                        --border: #d9e0e8;
                        --header-background: #1f4e79;
                        --group-background: #dce8f4;
                        --group-text: #163b5c;
                        --hover-background: #f5f9fd;
                    }

                    * {
                        box-sizing: border-box;
                    }

                    body {
                        margin: 0;
                        background: var(--page-background);
                        color: var(--text);
                        font-family: Arial, Helvetica, sans-serif;
                    }

                    main {
                        width: min(1800px, 100%);
                        margin: 0 auto;
                        padding: 36px 28px 56px;
                    }

                    h1 {
                        margin: 0;
                        font-size: 30px;
                    }

                    .metadata {
                        margin: 10px 0 30px;
                        color: var(--muted-text);
                    }

                    .report-section {
                        margin-top: 28px;
                        padding: 22px;
                        background: var(--card-background);
                        border: 1px solid var(--border);
                        border-radius: 10px;
                        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
                    }

                    h2 {
                        margin: 0 0 16px;
                        font-size: 21px;
                    }

                    .table-container {
                        overflow-x: auto;
                        border: 1px solid var(--border);
                        border-radius: 7px;
                    }

                    table {
                        width: 100%;
                        min-width: 1050px;
                        border-collapse: collapse;
                        font-size: 14px;
                    }

                    thead th {
                        position: sticky;
                        top: 0;
                        z-index: 1;
                        background: var(--header-background);
                        color: white;
                        text-align: right;
                        white-space: nowrap;
                    }

                    th,
                    td {
                        padding: 10px 13px;
                        border-bottom: 1px solid var(--border);
                    }

                    tbody td {
                        text-align: right;
                        white-space: nowrap;
                        font-variant-numeric: tabular-nums;
                    }

                    .variable-column {
                        min-width: 280px;
                        text-align: left;
                        white-space: nowrap;
                    }

                    tbody th.variable-column {
                        font-weight: 500;
                    }

                    tbody tr:not(.group-row):hover {
                        background: var(--hover-background);
                    }

                    .group-row th {
                        background: var(--group-background);
                        color: var(--group-text);
                        text-align: left;
                        font-weight: 700;
                    }

                    footer {
                        margin-top: 26px;
                        color: var(--muted-text);
                        font-size: 13px;
                    }
                </style>
            </head>

            <body>
                <main>
            """,
        )

        println(io, "<h1>Vietnam Merged Model — Simulation Report</h1>")

        println(
            io,
            """
            <p class="metadata">
                Base year: $(results.base_year)
                &nbsp;|&nbsp;
                Projection horizon: $(first(results.projection_years))–$(last(results.projection_years))
            </p>
            """,
        )

        write_html_table!(
            io,
            results,
            "Variable Values after Simulation — Exogenous",
            exogenous_rows,
        )

        write_html_table!(
            io,
            results,
            "Variable Values after Simulation — Endogenous",
            endogenous_rows,
        )

        write_html_table!(
            io,
            results,
            "Checking % Change — Endogenous Variables",
            change_rows;
            percent_change = true,
        )

        print(
            io,
            """
                    <footer>
                        Generated by the Vietnam Merged Model.
                    </footer>
                </main>
            </body>
            </html>
            """,
        )
    end

    return report_file
end

function open_html_in_browser(report_file::AbstractString)
    absolute_path = abspath(report_file)

    file_url =
        "file:///" *
        replace(
            replace(absolute_path, '\\' => '/'),
            " " => "%20",
        )

    try
        if Sys.iswindows()
            run(
                Cmd(["cmd", "/c", "start", "", file_url]);
                wait = false,
            )

        elseif Sys.isapple()
            run(`open $absolute_path`; wait = false)

        else
            run(`xdg-open $absolute_path`; wait = false)
        end

    catch err
        @warn(
            "Could not open the HTML report automatically.",
            report_file,
            exception = err,
        )
    end

    return nothing
end