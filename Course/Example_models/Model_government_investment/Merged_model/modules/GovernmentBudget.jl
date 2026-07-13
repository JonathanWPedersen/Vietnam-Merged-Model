module GovernmentBudget
import JuMP
using SquareModels

function define_equations(db, vars; public_investment_types, proj)
    (; BRG, CG, DCG, INDG, INFG, NDDG, NFDG,
       X, GT, IVG, IVGI, NTRG, TG, E, PD, XPI,
       g, irdg, irfg, ivggr) = vars

    return @block db begin

        # =====================================================================
        # Extensions
        # =====================================================================        

        IVGI[i = public_investment_types, t = proj],
            IVGI[i, t] ==
                (1 + ivggr[i, t]) * IVGI[i, t - 1]

        IVG[t = proj],
            IVG[t] ==
                sum(IVGI[i, t] for i in public_investment_types)

        
        # =====================================================================
        # Equations (14)-(16): Government budget and debt
        # =====================================================================

        BRG[t = proj],
            BRG[t] ==
                PD[t] * (CG[t] + IVG[t]) +
                (GT[t] - TG[t]) +
                INDG[t] +
                E[t] * (INFG[t] - NTRG[t])                    # Eq. 14

        DCG[t = proj],
            BRG[t] ==
                E[t] * (NFDG[t] - NFDG[t - 1]) +
                (NDDG[t] - NDDG[t - 1]) +
                (DCG[t] - DCG[t - 1])                         # Eq. 15

        NFDG[t = proj],
            NFDG[t] ==
                g[t] * XPI[t] * X[t]                          # Eq. 16

        # =====================================================================
        # Equations (27)-(28): Government interest payments
        # =====================================================================

        INDG[t = proj],
            INDG[t] ==
                irdg[t] * NDDG[t - 1]                         # Eq. 27

        INFG[t = proj],
            INFG[t] ==
                irfg[t] * NFDG[t - 1]                         # Eq. 28
    end
end

end