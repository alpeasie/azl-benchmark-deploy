#requires -Version 7.0

$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

$tenant = "dcea112b-ec40-4856-b620-d8f34929a0e3"
$sub    = "fbacedb7-2b65-412b-8b80-f8288b6d7b12"

# Read current context (null if not logged in)
$ctx = az account show --only-show-errors 2>$null | ConvertFrom-Json

# If not logged in, wrong tenant, or wrong subscription => log in & set it
if (-not $ctx -or $ctx.tenantId -ne $tenant -or $ctx.id -ne $sub) {
  az login --tenant $tenant --only-show-errors | Out-Null
  az account set --subscription $sub | Out-Null
  $ctx = az account show --only-show-errors | ConvertFrom-Json
}

# Final check / message
if ($ctx.tenantId -eq $tenant -and $ctx.id -eq $sub) {
  Write-Host "Azure context OK. Tenant=$tenant  Subscription=$sub"
} else {
  throw "Azure context NOT set. Current tenant=$($ctx.tenantId) subscription=$($ctx.id)"
}


$ResourceGroup = "azlrg3"

# Get storage path ID
$storagePathId = az stack-hci-vm storagepath list --resource-group $ResourceGroup --query "[?starts_with(name, 'UserStorage2-')].id | [0]" -o tsv

if ([string]::IsNullOrWhiteSpace($storagePathId)) {
  throw "No storage path with a name starting 'UserStorage2-' found in RG"
}
Write-Host "Using Storage Path: $storagePathId"


# Create the Azure Local image on your cluster from Marketplace
#$urn1 = "MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition-core:latest"
#$urn2 = "MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition-core:26100.4652.250808"

$customLocationId = "/subscriptions/fbacedb7-2b65-412b-8b80-f8288b6d7b12/resourceGroups/azlrg3/providers/Microsoft.ExtendedLocation/customLocations/jumpstart"
$publisher = 'microsoftwindowsserver'
$offer = 'windowsserver'
$sku = "2025-datacenter-azure-edition-core"
$version = "26100.4652.250808" 
$imgResourceName = "azcl3img1"

Write-Host "Creating VM Image"

az stack-hci-vm image create --resource-group $ResourceGroup --custom-location $customLocationId --name $imgResourceName --os-type "Windows" --offer $offer --publisher $publisher --sku $sku --verbose --version $version

Write-Host "Done." -ForegroundColor Green
