module BalanceOfPayments
import JuMP
using SquareModels

using SquareModels

function define_equations(db, vars; proj)
    (; RESBAL, NETFSY, CURBAL, NFDP, INFG, INFP,
       NFDG, R, X, M, NFP, NTRG, NTRP, FDI,
       XPI, MPI, irfp) = vars

    return @block db begin
        # =====================================================================
        # Equation (29): Interest on private foreign debt
        # =====================================================================

        INFP[t = proj],
            INFP[t] ==
                irfp[t] * NFDP[t - 1]                         # Eq. 29

        # =====================================================================
        # Equations (23)-(26): Balance of payments
        # =====================================================================

        RESBAL[t = proj],
            RESBAL[t] ==
                XPI[t] * X[t] -
                MPI[t] * M[t]                                 # Eq. 23

        NETFSY[t = proj],
            NETFSY[t] ==
                NFP[t] -
                INFG[t] -
                INFP[t]                                       # Eq. 24

        CURBAL[t = proj],
            CURBAL[t] ==
                RESBAL[t] +
                NETFSY[t] +
                NTRG[t] +
                NTRP[t]                                       # Eq. 25

        NFDP[t = proj],
            R[t] - R[t - 1] ==
                CURBAL[t] +
                (NFDG[t] - NFDG[t - 1]) +
                (NFDP[t] - NFDP[t - 1]) +
                FDI[t]                                        # Eq. 26
    end
end

end 