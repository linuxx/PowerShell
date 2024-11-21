# Ensure the Microsoft.Graph module is loaded
Import-Module Microsoft.Graph

# Connect to Microsoft Graph if not already connected
if (!(Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" -UseDeviceAuthentication
}

# Define SkuIds
$noTeamsSkuId = "46c3a859-c90d-40b3-9551-6178a48d5c18" # Office_365_E3_(no_Teams)
$teamsSkuId = "7e31c0d9-9551-471d-836f-32ee72be4a01"   # Microsoft_Teams_Enterprise_New

# Fetch only members from Azure AD
$users = Get-MgUser -All -Property DisplayName, UserPrincipalName, AssignedLicenses, UserType | Where-Object { $_.UserType -eq "Member" }

foreach ($user in $users) {
    # Check if the user has the Office_365_E3_(no_Teams) license
    $hasNoTeams = $user.AssignedLicenses | Where-Object { $_.SkuId -eq $noTeamsSkuId }
    $hasTeams = $user.AssignedLicenses | Where-Object { $_.SkuId -eq $teamsSkuId }
    
    if ($hasNoTeams -and -not $hasTeams) {
        Write-Host "Adding Teams license for user: $($user.DisplayName) ($($user.UserPrincipalName))"

        # Assign the Teams license to the user
        try {
            Set-MgUserLicense -UserId $user.UserPrincipalName -AddLicenses @{ SkuId = $teamsSkuId } -RemoveLicenses @()
            Write-Host "Successfully added Teams license to $($user.DisplayName)"
        } catch {
            Write-Warning "Failed to add Teams license to $($user.DisplayName): $_"
        }
    } elseif ($hasTeams) {
        Write-Host "$($user.DisplayName) already has Teams license."
    } else {
        Write-Host "$($user.DisplayName) does not have Office_365_E3_(no_Teams) license."
    }
}
