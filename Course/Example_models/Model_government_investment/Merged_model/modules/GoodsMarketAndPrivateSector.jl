module GoodsMarketAndPrivateSector
import JuMP
using SquareModels

using SquareModels

function define_equations(db, vars; sectors, proj, base_period)
    (; GDPS, GDP, XS, X, IV, M, C, CG, CP, IVP,
       GDY, GDS, INDG, INFG, INFP, P, GT, IVG,
       NFP, NTRG, NTRP, TG, E, MPI, PD, XPI,
       gamma, xgr, k0, k1, m0, m1, m2, b) = vars

    return @block db begin
        # =====================================================================
        # Equations (1)-(13): Goods market and private sector
        # =====================================================================

        GDPS[s = sectors, t = proj],
            GDPS[s, t] ==
                (1 + gamma[s, t]) * GDPS[s, t - 1]            # Eq. 1

        GDP[t = proj],
            GDP[t] ==
                sum(GDPS[s, t] for s in sectors)              # Eq. 2

        XS[s = sectors, t = proj],
            XS[s, t] ==
                (1 + xgr[s, t]) * XS[s, t - 1]                # Eq. 3

        X[t = proj],
            X[t] ==
                sum(XS[s, t] for s in sectors)                # Eq. 4

        IV[t = proj],
            IV[t] ==
                k0[t] * GDP[t - 1] +
                k1[t] * (GDP[t] - GDP[t - 1])                 # Eq. 5

        M[t = proj],
            log(M[t]) ==
                m0[t] +
                m1[t] * log(GDP[t]) +
                m2[t] * log(E[t] * MPI[t] / PD[t])           # Eq. 6

        CG[t = proj],
            C[t] == CP[t] + CG[t]                             # Eq. 7

        IVP[t = proj],
            IV[t] == IVP[t] + IVG[t]                          # Eq. 8

        CP[t = proj],
            PD[t] * CP[t] ==
                (1 - b[t]) * GDY[t]                           # Eq. 9

        P[t = proj],
            P[t] * GDP[t] ==
                PD[t] * (C[t] + IV[t]) +
                E[t] * (XPI[t] * X[t] - MPI[t] * M[t])        # Eq. 10

        C[t = proj],
            P[base_period] * GDP[t] ==
                PD[base_period] * (C[t] + IV[t]) +
                E[base_period] *
                (
                    XPI[base_period] * X[t] -
                    MPI[base_period] * M[t]
                )                                             # Eq. 11

        GDY[t = proj],
            GDY[t] ==
                P[t] * GDP[t] +
                E[t] * NFP[t] +
                E[t] * NTRP[t] +
                INDG[t] +
                (GT[t] - TG[t]) -
                E[t] * INFP[t]                                # Eq. 12

        GDS[t = proj],
            GDS[t] ==
                P[t] * GDP[t] +
                E[t] * (NFP[t] - INFG[t] - INFP[t]) +
                E[t] * (NTRP[t] + NTRG[t]) -
                PD[t] * C[t]                                  # Eq. 13
    end
end

end 