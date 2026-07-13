# ==============================================================================
# Variable declarations
# ==============================================================================

function declare_variables!(db, sets, years, proj)
    sectors = sets.sectors
    public_investment_types = sets.public_investment_types

    JuMP.@variables db.model begin
        # ----------------------------------------------------------------------
        # Endogenous flow variables
        # ----------------------------------------------------------------------

        GDPS[sectors, years] >= 1e-9
        GDP[years] >= 1e-9

        XS[sectors, years] >= 1e-9
        X[years] >= 1e-9

        IV[years] >= 1e-9
        M[years] >= 1e-9

        C[years]
        CG[years]
        CP[years]
        IVP[years]

        GDY[years]
        GDS[years]

        BRG[years]
        GDPN[years]

        RESBAL[years]
        NETFSY[years]
        CURBAL[years]

        INDG[years]
        INFG[years]
        INFP[years]

        IVG[years]
        IVGI[public_investment_types, years] >= 1e-9

        # ----------------------------------------------------------------------
        # Endogenous stock variables
        # ----------------------------------------------------------------------

        DC[years]
        DCG[years]
        DCP[years]

        MD[years]
        MS[years]
        R[years]

        NFDG[years]
        NFDP[years]

        # ----------------------------------------------------------------------
        # Endogenous price variable
        # ----------------------------------------------------------------------

        P[years] >= 1e-9

        # ----------------------------------------------------------------------
        # Exogenous flow variables
        # ----------------------------------------------------------------------

        FDI[years]
        GT[years]
        NFP[years]
        NTRG[years]
        NTRP[years]
        TG[years]

        # ----------------------------------------------------------------------
        # Exogenous stock variable
        # ----------------------------------------------------------------------

        NDDG[years]

        # ----------------------------------------------------------------------
        # Exogenous price variables
        # ----------------------------------------------------------------------

        E[years] >= 1e-9
        MPI[years] >= 1e-9
        PD[years] >= 1e-9
        XPI[years] >= 1e-9

        # ----------------------------------------------------------------------
        # Parameters and assumptions
        # ----------------------------------------------------------------------

        gamma[sectors, proj]
        xgr[sectors, proj]

        k0[proj]
        k1[proj]

        m0[proj]
        m1[proj]
        m2[proj]

        b[proj]

        irdg[years]
        irfg[years]
        irfp[years]
        ivggr[public_investment_types, proj]

        g[proj]
        v[proj]
        d[proj]
    end

    return (;
        GDPS,
        GDP,
        XS,
        X,
        IV,
        M,
        C,
        CG,
        CP,
        IVP,
        GDY,
        GDS,
        BRG,
        GDPN,
        RESBAL,
        NETFSY,
        CURBAL,
        INDG,
        INFG,
        INFP,
        DC,
        DCG,
        DCP,
        MD,
        MS,
        R,
        NFDG,
        NFDP,
        P,
        FDI,
        GT,
        IVG,
        IVGI,
        NFP,
        NTRG,
        NTRP,
        TG,
        NDDG,
        E,
        MPI,
        PD,
        XPI,
        gamma,
        xgr,
        ivggr,
        k0,
        k1,
        m0,
        m1,
        m2,
        b,
        irdg,
        irfg,
        irfp,
        g,
        v,
        d,
    )
end

# ==============================================================================
# Output variables for prints and such
# ==============================================================================

const OUTPUT_KEYS = Any[
    :GDP,
    :X,
    :IV,
    :M,
    :C,
    :CG,
    :CP,
    :IVP,
    :IVG,
    :P,
    :GDY,
    :GDS,
    :BRG,
    :GDPN,
    :RESBAL,
    :NETFSY,
    :CURBAL,
    :INDG,
    :INFG,
    :INFP,
    :NFDG,
    :DCG,
    :MD,
    :MS,
    :R,
    :DC,
    :DCP,
    :NFDP,

    [(:GDPS, sector) for sector in MODEL_SETS.sectors]...,
    [(:XS, sector) for sector in MODEL_SETS.sectors]...,
    [(:IVGI, type) for type in MODEL_SETS.public_investment_types]...,
]