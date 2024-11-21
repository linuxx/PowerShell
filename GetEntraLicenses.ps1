# Ensure the Microsoft.Graph module is loaded
Import-Module Microsoft.Graph

# Connect to Microsoft Graph if not already connected
if (!(Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" -UseDeviceAuthentication
}

# Load all subscribed SKUs into memory
$skuList = Get-MgSubscribedSku | Select-Object SkuId, SkuPartNumber

# Fetch only members from Azure AD
$users = Get-MgUser -All -Property DisplayName, UserPrincipalName, AssignedLicenses, UserType | Where-Object { $_.UserType -eq "Member" }

# Create an array to store results
$results = @()

foreach ($user in $users) {
    # Retrieve assigned licenses
    $licenses = $user.AssignedLicenses | ForEach-Object { $_.SkuId }
    
    # Lookup readable license names from the in-memory SKU list
    $licenseNames = @()
    foreach ($skuId in $licenses) {
        $sku = $skuList | Where-Object { $_.SkuId -eq $skuId }
        if ($sku) {
            $licenseNames += $sku.SkuPartNumber
        } else {
            $licenseNames += "Unknown License"
        }
    }
    
    # Handle cases where no licenses are assigned
    if (-not $licenseNames) {
        $licenseNames = @("No Licenses Assigned")
    }

    # Create a user object with all details
    $results += [PSCustomObject]@{
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        Licenses          = $licenseNames -join ", "
    }
}

# Export to CSV or display in console
$results | Export-Csv -Path "EntraMembersAndLicenses.csv" -NoTypeInformation -Encoding UTF8
Write-Output $results
