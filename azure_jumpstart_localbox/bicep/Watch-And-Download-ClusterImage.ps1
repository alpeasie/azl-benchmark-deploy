<#!
Waits for the Azure Local (Arc-enabled Azure Stack HCI) cluster (default: azlcluster3 in azlrg3)
to finish provisioning, then (optionally) downloads a Windows Server 2019 Datacenter Azure Edition
Core Gen2 marketplace gallery image to the cluster via the Azure CLI 'stack-hci' extension.

Safe to re-run: it will skip image creation if already present.

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

if (-not $SkipLogin) {
  Write-Stage "Azure login"
  az login --tenant dcea112b-ec40-4856-b620-d8f34929a0e3 | Out-Null
}

Write-Stage "Ensuring stack-hci CLI extension"
$ext = az extension list --query "[?name=='stack-hci'].version" -o tsv 2>$null
if (-not $ext) {
  az extension add --name stack-hci | Out-Null
  Write-Info "Installed stack-hci extension"
} else {
  az extension update --name stack-hci | Out-Null
  Write-Info "Updated stack-hci extension (was $ext)"
}

function Invoke-AzJson {
  param([string[]]$AzArgs)
  $raw = az @AzArgs 2>$null
  if (-not $raw) { return $null }
  try { return $raw | ConvertFrom-Json } catch { return $raw }
}

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
$storagePaths = $null
try {
  $storagePathsJson = az resource show -g $ResourceGroup -n $ClusterName --resource-type Microsoft.AzureStackHCI/clusters --query properties.storageProfile.storagePaths -o json 2>$null
  if ($storagePathsJson -and $storagePathsJson -notin @('null','')) { $storagePaths = $storagePathsJson | ConvertFrom-Json }
} catch { Write-Warn "Unable to read storage paths: $($_.Exception.Message)" }

if (-not $storagePaths) { Write-Warn "No storage paths discovered. Provide -StoragePathName if required by your environment." }

$chosenPath = $null
if ($StoragePathName) {
  $chosenPath = $storagePaths | Where-Object { $_.name -ieq $StoragePathName }
  if (-not $chosenPath) { Write-Warn "Specified -StoragePathName '$StoragePathName' not found; proceeding without explicit path." }
} else {
  if ($storagePaths) {
    $preferred = $storagePaths | Where-Object { $_.name -ieq 'storagepath2' } | Select-Object -First 1
    $chosenPath = if ($preferred) { $preferred } else { $storagePaths | Select-Object -First 1 }
  }
}
if ($chosenPath) { Write-Info "Selected storage path: $($chosenPath.name)" } else { Write-Info "No explicit storage path selected." }

Write-Stage "Existing gallery images"
$existingImages = Invoke-AzJson -AzArgs @('stack-hci','marketplace','gallery-image','list','--resource-group',$ResourceGroup,'--cluster-name',$ClusterName)
if ($existingImages) {
  foreach ($img in $existingImages) {
    Write-Info ("Found image: {0} ({1}/{2}/{3}) State={4}" -f $img.name,$img.properties.publisher,$img.properties.offer,$img.properties.sku,$img.properties.provisioningState)
  }
} else {
  Write-Info "No existing gallery images returned."
}

if ($DiscoverMarketplace) {
  Write-Stage "Discovery mode only - no creation" 'Yellow'
  $summary = [pscustomobject]@{
    mode              = 'discovery'
    resourceGroup     = $ResourceGroup
    clusterName       = $ClusterName
    provisioningState = $provisioningState
    storagePaths      = $storagePaths
    existingImages    = $existingImages
    elapsedMinutes    = [math]::Round(((Get-Date)-$startTime).TotalMinutes,2)
  }
  $json = $summary | ConvertTo-Json -Depth 6
  $json
  if ($OutputJson) { $json | Out-File -Encoding UTF8 $OutputJson; Write-Info "Wrote summary to $OutputJson" }
  return
}

$imageAlready = $false
if ($existingImages) {
  $imageAlready = $existingImages | Where-Object {
    $_.name -ieq $TargetImageName -or (
      $_.properties.publisher -ieq $Publisher -and
      $_.properties.offer -ieq $Offer -and
      $_.properties.sku -ieq $Sku
    )
  } | Select-Object -First 1
}

if ($imageAlready) {
  Write-Stage "Image already present - skipping create" 'Yellow'
} else {
  Write-Stage "Creating gallery image"
  $createArgs = @(
    'stack-hci','marketplace','gallery-image','create',
    '--resource-group',$ResourceGroup,
    '--cluster-name',$ClusterName,
    '--name',$TargetImageName,
    '--publisher',$Publisher,
    '--offer',$Offer,
    '--sku',$Sku,
    '--version',$Version,
    '--os-type','Windows'
  )
  if ($chosenPath -and $chosenPath.id) {
    $createArgs += @('--storage-path-id',$chosenPath.id)
  } elseif ($chosenPath -and $chosenPath.name) {
    $createArgs += @('--storage-path-name',$chosenPath.name)
  }
  Write-Info "Invoking: az $($createArgs -join ' ')"
  $createResultRaw = az @createArgs 2>&1
  Write-Info $createResultRaw
  Start-Sleep -Seconds 20
}

Write-Stage "Final image list"
$finalImages = Invoke-AzJson -AzArgs @('stack-hci','marketplace','gallery-image','list','--resource-group',$ResourceGroup,'--cluster-name',$ClusterName)
$targetFinal = $finalImages | Where-Object { $_.name -ieq $TargetImageName } | Select-Object -First 1
if ($targetFinal) { Write-Info "Target image provisioningState: $($targetFinal.properties.provisioningState)" }
else { Write-Warn "Target image not visible yet (may still be provisioning asynchronously)." }

$summary = [pscustomobject]@{
  resourceGroup     = $ResourceGroup
  clusterName       = $ClusterName
  clusterState      = $provisioningState
  targetImageName   = $TargetImageName
  publisher         = $Publisher
  offer             = $Offer
  sku               = $Sku
  version           = $Version
  storagePathChosen = $chosenPath
  images            = $finalImages
  elapsedMinutes    = [math]::Round(((Get-Date)-$startTime).TotalMinutes,2)
}

$summaryJson = $summary | ConvertTo-Json -Depth 8
$summaryJson
if ($OutputJson) { $summaryJson | Out-File -Encoding UTF8 $OutputJson; Write-Info "Wrote summary JSON to $OutputJson" }

Write-Host "Done." -ForegroundColor Green