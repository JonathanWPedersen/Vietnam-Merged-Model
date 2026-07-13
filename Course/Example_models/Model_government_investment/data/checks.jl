
function check_sam(sam::SAM; atol = 1e-6, warn_share_of_gdp = 0.01)
    GDP = sam.stocks[:GDPN]

    # Both SAMs must balance exactly after the balancing entries are posted.
    for (matrix, accounts, label) in (
        (sam.real, sam.real_accounts, "Real SAM"),
        (sam.financial, sam.financial_accounts, "Financial SAM"),
    )
        for (i, account) in enumerate(accounts)
            residual = sum(matrix[i, :]) - sum(matrix[:, i])
            abs(residual) <= atol ||
                error("$label does not balance for $account: residual = $residual")
        end
    end

    # Balancing entries are legitimate, but large ones signal an input problem.
    for (entry, value) in sam.balancing_entries
        share = abs(value) / GDP
        share > warn_share_of_gdp &&
            @warn "Large SAM balancing entry" entry value percent_of_gdp = 100share
    end

    reconciliation = sam.flows[:investment_reconciliation]
    share = abs(reconciliation) / GDP
    share > warn_share_of_gdp &&
        @warn "Large GSO/IMF trade reconciliation absorbed in investment" reconciliation percent_of_gdp = 100share

    return nothing
end