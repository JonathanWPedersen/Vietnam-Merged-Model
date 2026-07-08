using XLSX

# ==============================================================================
# Raw observed-data workbook reader
#
# The workbook contains historical observations only. All model assumptions,
# forward paths, calibration conventions, and normalisations belong in
# Data/assumptions.jl.
# ==============================================================================

struct YearTable
    values::Dict{Tuple{String, String, Int}, Float64}
    units::Dict{Tuple{String, String}, String}
    metadata::Dict{Tuple{String, String, String}, String}
end

struct RawInputs
    observed::YearTable
    workbook::String
end

# ==============================================================================
# Basic conversion helpers
# ==============================================================================

function clean_text(value)
    value === nothing && return nothing
    value === missing && return nothing

    text = strip(string(value))

    return isempty(text) ? nothing : text
end

function as_float(value)
    value === nothing && return nothing
    value === missing && return nothing

    value isa Number && return Float64(value)

    text = strip(string(value))
    isempty(text) && return nothing

    parsed = tryparse(
        Float64,
        replace(text, "," => ""),
    )

    return parsed === nothing ? nothing : parsed
end

function as_year(value)
    value isa Integer && return Int(value)

    if value isa AbstractFloat && isinteger(value)
        return Int(value)
    end

    text = clean_text(value)
    text === nothing && return nothing

    match_result = match(r"^(19|20)\d{2}$", text)

    return match_result === nothing ? nothing : parse(Int, text)
end

function find_header_row(
    data,
    required_headers::Vector{String},
)
    for row in axes(data, 1)
        headers = Set{String}()

        for col in axes(data, 2)
            header = clean_text(data[row, col])

            header === nothing || push!(headers, header)
        end

        all(
            header -> header in headers,
            required_headers,
        ) && return row
    end

    error(
        "Could not find a header row containing: " *
        join(required_headers, ", "),
    )
end

function header_columns(
    data,
    header_row::Int,
)
    columns = Dict{String, Int}()

    for col in axes(data, 2)
        header = clean_text(data[header_row, col])

        header === nothing || (columns[header] = col)
    end

    return columns
end

# ==============================================================================
# Generic observed-data table reader
# ==============================================================================

function read_year_table(
    workbook::AbstractString,
    sheet::AbstractString;
    first_key_header::String,
    second_key_header::String,
    unit_header::String = "Unit",
)
    raw = XLSX.readdata(
        workbook,
        sheet,
        "A1:Z500",
    )

    header_row = find_header_row(
        raw,
        [
            first_key_header,
            second_key_header,
            unit_header,
        ],
    )

    columns = header_columns(raw, header_row)

    first_key_col = columns[first_key_header]
    second_key_col = columns[second_key_header]
    unit_col = columns[unit_header]

    year_columns = Dict{Int, Int}()

    for col in axes(raw, 2)
        year = as_year(raw[header_row, col])

        year === nothing || (year_columns[year] = col)
    end

    isempty(year_columns) &&
        error("No year columns found on sheet '$sheet'.")

    values = Dict{Tuple{String, String, Int}, Float64}()
    units = Dict{Tuple{String, String}, String}()
    metadata = Dict{Tuple{String, String, String}, String}()

    for row in (header_row + 1):size(raw, 1)
        first_key = clean_text(raw[row, first_key_col])
        second_key = clean_text(raw[row, second_key_col])

        first_key === nothing && continue
        second_key === nothing && continue

        key = (first_key, second_key)

        unit = clean_text(raw[row, unit_col])

        unit === nothing || (units[key] = unit)

        for (year, col) in year_columns
            value = as_float(raw[row, col])

            value === nothing && continue

            value_key = (
                first_key,
                second_key,
                year,
            )

            haskey(values, value_key) && error(
                "Duplicate value for '$first_key' / '$second_key' " *
                "in $year on sheet '$sheet'.",
            )

            values[value_key] = value
        end

        for (header, col) in columns
            header in (
                first_key_header,
                second_key_header,
                unit_header,
            ) && continue

            year = as_year(header)

            year !== nothing &&
                haskey(year_columns, year) &&
                continue

            value = clean_text(raw[row, col])

            value === nothing && continue

            metadata[(
                first_key,
                second_key,
                header,
            )] = value
        end
    end

    return YearTable(
        values,
        units,
        metadata,
    )
end

# ==============================================================================
# Lookup functions
# ==============================================================================

function table_value(
    table::YearTable,
    source_group::AbstractString,
    series::AbstractString,
    year::Integer,
)
    key = (
        String(source_group),
        String(series),
        Int(year),
    )

    haskey(table.values, key) || error(
        "Missing value for source group '$source_group', " *
        "series '$series', year $year.",
    )

    return table.values[key]
end

function table_metadata(
    table::YearTable,
    source_group::AbstractString,
    series::AbstractString,
    field::AbstractString;
    default = nothing,
)
    key = (
        String(source_group),
        String(series),
        String(field),
    )

    return get(
        table.metadata,
        key,
        default,
    )
end

function observed_value(
    raw::RawInputs,
    source_group::AbstractString,
    series::AbstractString,
    year::Integer,
)
    return table_value(
        raw.observed,
        source_group,
        series,
        year,
    )
end

# ==============================================================================
# Public reader entry point
# ==============================================================================

function read_inputs(workbook::AbstractString)
    isfile(workbook) ||
        error("Workbook not found: $workbook")

    observed = read_year_table(
        workbook,
        "Observed Data";
        first_key_header = "Source group",
        second_key_header = "Series",
    )

    return RawInputs(
        observed,
        String(workbook),
    )
end