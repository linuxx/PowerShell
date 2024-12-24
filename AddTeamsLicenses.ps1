# Ensure the Microsoft.Graph module is loaded
Import-Module Microsoft.Graph

# Connect to Microsoft Graph if not already connected
if (!(Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" -UseDeviceAuthentication
}

# Configuration flags
$TestMode = $true # Set to $true for testing (no changes made, only outputs actions); $false to apply changes.
$LimitOne = $false # Set to $true to only process one user (for testing purposes).

# Define SkuIds
$noTeamsSkuId = "dcf0408c-aaec-446c-afd4-43e3683943ea" # Microsoft 365 E3 (no Teams)
$fullTeamsSkuId = "05e9a617-0261-4cee-bb44-138d3ef5d965" # Microsoft 365 E3
$teamsEnterpriseSkuId = "7e31c0d9-9551-471d-836f-32ee72be4a01" # Microsoft Teams Enterprise New

# Fetch users from Azure AD with the desired filters
$users = if ($LimitOne) {
    Get-MgUser -Top 1 -Property DisplayName, UserPrincipalName, AssignedLicenses, UserType |
        Where-Object { $_.UserType -eq "Member" }
} else {
    Get-MgUser -All -Property DisplayName, UserPrincipalName, AssignedLicenses, UserType |
        Where-Object { $_.UserType -eq "Member" }
}

foreach ($user in $users) {
    # Check license assignments for the user
    $hasFullTeams = $user.AssignedLicenses | Where-Object { $_.SkuId -eq $fullTeamsSkuId }
    $hasNoTeams = $user.AssignedLicenses | Where-Object { $_.SkuId -eq $noTeamsSkuId }
    $hasTeamsEnterprise = $user.AssignedLicenses | Where-Object { $_.SkuId -eq $teamsEnterpriseSkuId }

    # Perform actions only if the user has "Full Teams" license
    if ($hasFullTeams) {
        Write-Host "Processing user: $($user.DisplayName) ($($user.UserPrincipalName))"

        if ($TestMode) {
            Write-Host "[TEST MODE] Would remove license $fullTeamsSkuId and add $noTeamsSkuId and $teamsEnterpriseSkuId"
        } else {
            try {
                # Perform license swap
                Set-MgUserLicense -UserId $user.UserPrincipalName \
                    -AddLicenses @(@{ SkuId = $noTeamsSkuId }, @{ SkuId = $teamsEnterpriseSkuId }) \
                    -RemoveLicenses $fullTeamsSkuId
                Write-Host "Successfully swapped licenses for $($user.DisplayName)"
            } catch {
                Write-Warning "Failed to swap licenses for $($user.DisplayName): $_"
            }
        }
    } elseif ($hasNoTeams -and $hasTeamsEnterprise) {
        Write-Host "$($user.DisplayName) already has the desired licenses (No Teams and Teams Enterprise)."
    } else {
        Write-Host "$($user.DisplayName) does not have Microsoft 365 E3 (Full Teams) license or already has the correct licenses."
    }
}
