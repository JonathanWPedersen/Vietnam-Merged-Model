module MoneyMarket
import JuMP
using SquareModels

function define_equations(db, vars; proj)
    (; GDPN, GDP, P, MD, MS, DC, DCG, DCP,
       R, E, M, MPI, v, d) = vars

    return @block db begin
        # =====================================================================
        # Equations (17)-(22): Money market
        # =====================================================================

        GDPN[t = proj],
            GDPN[t] ==
                P[t] * GDP[t]                                 # Eq. 17

        MD[t = proj],
            MD[t] ==
                (1 / v[t]) * GDPN[t]                          # Eq. 18

        DC[t = proj],
            MS[t] - MS[t - 1] ==
                (E[t] * R[t] - E[t - 1] * R[t - 1]) +
                (DC[t] - DC[t - 1])                           # Eq. 19

        R[t = proj],
            R[t] - R[t - 1] ==
                d[t] *
                (MPI[t] * M[t] - MPI[t - 1] * M[t - 1]) /
                E[t]                                          # Eq. 20

        DCP[t = proj],
            DC[t] ==
                DCG[t] + DCP[t]                               # Eq. 21

        MS[t = proj],
            MS[t] ==
                MD[t]                                         # Eq. 22
    end
end

end 