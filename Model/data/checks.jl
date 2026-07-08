# ==============================================================================
# Internal checks
# ==============================================================================

const REQUIRED_INITIAL_KEYS = Any[
    :GDP,
    :X,
    :M,
    :P,

    :E,
    :PD,
    :MPI,
    :XPI,

    (:GDPS, :agriculture),
    (:GDPS, :industry),
    (:GDPS, :services),

    (:XS, :agriculture),
    (:XS, :industry),
    (:XS, :services),

    :NDDG,
    :NFDG,
    :NFDP,
    :R,
    :DC,
    :DCG,
    :DCP,
    :MD,
    :MS,

    :GDPN,
]

const REQUIRED_PATHS = (
    :E,
    :PD,
    :MPI,
    :XPI,
    :GT,
    :TG,
    :IVG,
    :NDDG,
    :NFP,
    :NTRG,
    :NTRP,
    :FDI,
)

const REQUIRED_PARAMETERS = (
    :b,
    :d,
    :g,
    :k0,
    :k1,
    :m0,
    :m1,
    :m2,
    :v,
    :irdg,
    :irfg,
    :irfp,
)

function check_required_initial_inputs(initial)
    for key in REQUIRED_INITIAL_KEYS
        haskey(initial, key) ||
            error("Missing initial value: $(repr(key)).")

        isfinite(initial[key]) ||
            error("Initial value $(repr(key)) is not finite.")
    end

    return nothing
end

function assert_small(residual, label; atol = 1e-6)
    abs(residual) <= atol ||
        error("$label failed: residual = $residual.")

    return nothing
end

function check_path(series, key, label, horizon)
    haskey(series, key) ||
        error("Missing $label: $(repr(key)).")

    values = series[key]

    values isa AbstractVector ||
        error("$label $(repr(key)) must be a vector.")

    length(values) == horizon ||
        error(
            "$label $(repr(key)) has $(length(values)) values; " *
            "expected $horizon.",
        )

    all(isfinite, values) ||
        error("$label $(repr(key)) contains a non-finite value.")

    return values
end

function check_sam_balance(sam; atol = 1e-6)
    for (matrix, accounts, label) in (
        (sam.real, sam.real_accounts, "Real SAM"),
        (sam.financial, sam.financial_accounts, "Financial SAM"),
    )
        for (i, account) in enumerate(accounts)
            residual = sum(matrix[i, :]) - sum(matrix[:, i])

            assert_small(
                residual,
                "$label account $account";
                atol,
            )
        end
    end

    return nothing
end

function check_base_year(base; atol = 1e-6)
    v = base.values

    check_required_initial_inputs(v)

    assert_small(v[:C] - v[:CP] - v[:CG], "C = CP + CG"; atol)
    assert_small(v[:IV] - v[:IVP] - v[:IVG], "IV = IVP + IVG"; atol)
    assert_small(v[:DC] - v[:DCP] - v[:DCG], "DC = DCP + DCG"; atol)
    assert_small(v[:MS] - v[:MD], "MS = MD"; atol)

    assert_small(
        v[:RESBAL] - (v[:XPI] * v[:X] - v[:MPI] * v[:M]),
        "RESBAL identity";
        atol,
    )

    assert_small(
        v[:NETFSY] - (v[:NFP] - v[:INFG] - v[:INFP]),
        "NETFSY identity";
        atol,
    )

    assert_small(
        v[:CURBAL] - (v[:RESBAL] + v[:NETFSY] + v[:NTRG] + v[:NTRP]),
        "CURBAL identity";
        atol,
    )

    assert_small(
        v[:BRG] -
        (
            v[:PD] * (v[:CG] + v[:IVG]) +
            (v[:GT] - v[:TG]) +
            v[:INDG] +
            v[:E] * (v[:INFG] - v[:NTRG])
        ),
        "BRG identity";
        atol,
    )

    assert_small(
        v[:GDY] -
        (
            v[:P] * v[:GDP] +
            v[:E] * v[:NFP] +
            v[:E] * v[:NTRP] +
            v[:INDG] +
            (v[:GT] - v[:TG]) -
            v[:E] * v[:INFP]
        ),
        "GDY identity";
        atol,
    )

    assert_small(
        v[:GDS] -
        (
            v[:P] * v[:GDP] +
            v[:E] * (v[:NFP] - v[:INFG] - v[:INFP]) +
            v[:E] * (v[:NTRP] + v[:NTRG]) -
            v[:PD] * v[:C]
        ),
        "GDS identity";
        atol,
    )

    assert_small(
        sum(v[(:GDPS, sector)] for sector in SAM_SECTORS) - v[:GDP],
        "Sectoral GDP allocation";
        atol,
    )

    assert_small(
        sum(v[(:XS, sector)] for sector in SAM_SECTORS) - v[:X],
        "Sectoral export allocation";
        atol,
    )

    return nothing
end

function check_projection_paths(projection; horizon)
    for key in REQUIRED_PATHS
        values = check_path(
            projection.paths,
            key,
            "Projection path",
            horizon,
        )

        if key in (:E, :PD, :MPI, :XPI)
            all(value -> value > 0, values) ||
                error("Projection path $(repr(key)) must stay positive.")
        end
    end

    for sector in SAM_SECTORS
        check_path(
            projection.growth,
            (:gamma, sector),
            "GDP growth path",
            horizon,
        )

        check_path(
            projection.growth,
            (:xgr, sector),
            "Export growth path",
            horizon,
        )
    end

    for key in REQUIRED_PARAMETERS
        check_path(
            projection.parameters,
            key,
            "Parameter path",
            horizon,
        )
    end

    return nothing
end