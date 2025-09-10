#requires -Version 7.0
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

param(
  [string]$ResourceGroup,
  [string]$ClusterName
)

# Dot-source shared vars (ensures login & sets $LocalBoxContext), prefer explicit params
. "$PSScriptRoot\LocalBox.Vars.ps1" -ResourceGroup $ResourceGroup -ClusterName $ClusterName -EnsureLogin

$ctx = $Global:LocalBoxContext
$ResourceGroup     = $ctx.ResourceGroup
$customLocationId  = $ctx.CustomLocationId

Write-Host "Azure context OK. RG=$ResourceGroup  CustomLocation=$customLocationId"

# Get storage path ID (pattern unchanged)
$storagePathId = az stack-hci-vm storagepath list --resource-group $ResourceGroup --query "[?starts_with(name, 'UserStorage2-')].id | [0]" -o tsv
if ([string]::IsNullOrWhiteSpace($storagePathId)) {
  throw "No storage path with a name starting 'UserStorage2-' found in RG $ResourceGroup"
}
Write-Host "Using Storage Path: $storagePathId"

# Image variables inherit cluster-derived name now
$publisher       = 'microsoftwindowsserver'
$offer           = 'windowsserver'
$sku             = '2025-datacenter-azure-edition-core'
$version         = '26100.4652.250808'
$imgResourceName = "$($ctx.ClusterName)img1"  # per-cluster convention

Write-Host "Creating VM Image in RG $ResourceGroup for cluster $($ctx.ClusterName)"
az stack-hci-vm image create `
  --resource-group $ResourceGroup `
  --custom-location $customLocationId `
  --name $imgResourceName `
  --os-type Windows `
  --offer $offer `
  --publisher $publisher `
  --sku $sku `
  --version $version `
  --only-show-errors

Write-Host "Done." -ForegroundColor Green
