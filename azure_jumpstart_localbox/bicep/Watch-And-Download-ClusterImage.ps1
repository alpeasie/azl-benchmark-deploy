<#!
Waits for the Azure Local (Arc-enabled Azure Stack HCI) cluster (default: azlcluster3 in azlrg3)
to finish provisioning, then (optionally) downloads a Windows Server 2019 Datacenter Azure Edition
Core Gen2 marketplace gallery image to the cluster via the Azure CLI 'stack-hci' extension.

Safe to re-run: it will skip image creation if already present.

Step 1:
  az login --tenant dcea112b-ec40-4856-b620-d8f34929a0e3 



Examples:
  pwsh ./Watch-And-Download-ClusterImage.ps1                     # Full flow
  pwsh ./Watch-And-Download-ClusterImage.ps1 -DiscoverMarketplace # Just list existing images & storage paths
  pwsh ./Watch-And-Download-ClusterImage.ps1 -Sku 2019-datacenter-core-g2
  pwsh ./Watch-And-Download-ClusterImage.ps1 -StoragePathName storagepath2
  pwsh ./Watch-And-Download-ClusterImage.ps1 -OutputJson summary.json

Parameters:
  -ResourceGroup        Resource group containing the HCI cluster (default azlrg3)
  -ClusterName          Cluster resource name (default azlcluster3)
  -TargetImageName      Name for the gallery image resource to create
  -Publisher/Offer/Sku  Marketplace identifiers (adjust if discovery shows different ones)
  -Version              Version (often 'latest')
  -MaxWaitHours         Max time to wait for cluster provisioning (default 4h)
  -PollSeconds          Poll interval (default 300s)
  -SkipLogin            Assume already logged in (skip az login)
  -DiscoverMarketplace  Only list; do NOT create image
  -StoragePathName      Force specific storage path name; otherwise auto-select
  -OutputJson           Write summary JSON to path

Assumptions:
  - Azure CLI installed & recent (bicep integration not directly required here)
  - 'stack-hci' extension available or installable
  - The cluster registers marketplace capability and exposes gallery API
  - Storage paths appear under properties.storageProfile.storagePaths (may vary by API version)
!#>
[CmdletBinding()]
param(
  [string]$ResourceGroup = 'azlrg3',
  [string]$ClusterName = 'azlcluster3',
  [string]$TargetImageName = 'win2019-datacenter-azure-core-g2',
  [string]$Publisher = 'MicrosoftWindowsServer',
  [string]$Offer = 'WindowsServer',
  [string]$Sku = '2019-datacenter-azure-edition-core-g2',
  [string]$Version = 'latest',
  [double]$MaxWaitHours = 4,
  [int]$PollSeconds = 300,
  [switch]$SkipLogin,
  [switch]$DiscoverMarketplace,
  [string]$StoragePathName,
  [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
$startTime = Get-Date

function Write-Stage([string]$m,[string]$color='Cyan'){ Write-Host "==== $m ====\n" -ForegroundColor $color }
function Write-Info([string]$m){ Write-Host "[INFO] $m" -ForegroundColor DarkGray }
function Write-Warn([string]$m){ Write-Warning $m }
function Write-Err([string]$m){ Write-Host "[ERROR] $m" -ForegroundColor Red }


#az login --tenant dcea112b-ec40-4856-b620-d8f34929a0e3
#az config set extension.use_dynamic_install=yes_without_prompt | Out-Null




Write-Stage "Polling cluster provisioning state"
$deadline = (Get-Date).AddHours($MaxWaitHours)
$provisioningState = $null
do {
  $provisioningState = az resource show -g $ResourceGroup -n $ClusterName --resource-type Microsoft.AzureStackHCI/clusters --query properties.provisioningState -o tsv 2>$null
  if ($provisioningState) {
    Write-Info "Cluster state: $provisioningState"
    if ($provisioningState -in @('Succeeded','Failed','Canceled')) { break }
  } else {
    Write-Warn "Cluster state not returned yet."
  }
  if ((Get-Date) -ge $deadline) { throw "Timed out waiting for cluster > $MaxWaitHours hours. Last state: $provisioningState" }
  Start-Sleep -Seconds $PollSeconds
} while ($true)

if ($provisioningState -ne 'Succeeded') {
  throw "Cluster ended in terminal state '$provisioningState' (expected Succeeded). Aborting image download."
}

Write-Stage "Cluster succeeded; gathering storage paths"


#$imageName = "ws2025-dc-azure-edition"
#$publisher = "MicrosoftWindowsServer"
#$offer = "WindowsServer"
#$sku = "2025-datacenter-azure-edition"
#$version = "latest"
#$customLocationName = "jumpstart"
#$urn = '{0}:{1}:{2}:{3}' -f $publisher, $offer, $sku, $version


# Accept Marketplace terms (one-time per subscription for this plan)
#az vm image terms accept --publisher $publisher --offer $offer --plan $sku --only-show-errors 1>$null


# Variables for the marketplace image to download
$customLocationId = "/subscriptions/fbacedb7-2b65-412b-8b80-f8288b6d7b12/resourceGroups/azlrg3/providers/Microsoft.ExtendedLocation/customLocations/jumpstart"

# Get storage path ID
$storagePathId = az stack-hci-vm storagepath list --resource-group $ResourceGroup --query "[?starts_with(name, 'UserStorage2-')].id | [0]" -o tsv

if ([string]::IsNullOrWhiteSpace($storagePathId)) {
  throw "No storage path with a name starting 'UserStorage2-' found in RG"
}

Write-Host "Using Storage Path: $storagePathId"

# Create the Azure Local image on your cluster from Marketplace

$urn = "MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition:latest"

az stack-hci-vm image create `
  --resource-group $ResourceGroup `
  --custom-location $customLocationId `
  --name $imageName `
  --os-type Windows `
  --urn $urn `
  --storage-path-id $storagePathId 

Write-Host "Creating VM Image" 

Write-Host "Done." -ForegroundColor Green