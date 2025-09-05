<#
Purpose: Sequentially deploy the LocalBox Bicep template three times with different
         resource group names, cluster names, and deployment modes, then optionally delete them.

Scenarios:
 1. azlrg1 / azlcluster1 / none
 2. azlrg2 / azlcluster2 / validate
 3. azlrg3 / azlcluster3 / full

Overrides are passed inline so the shared parameter file can remain unchanged.

Usage examples (run from the bicep folder containing main.bicep):
  pwsh ./Deploy-MultipleLocalBox.ps1
  pwsh ./Deploy-MultipleLocalBox.ps1 -Cleanup            # Delete RGs after starting deployments
  pwsh ./Deploy-MultipleLocalBox.ps1 -WhatIfOnly         # Only run what-if for each scenario
  pwsh ./Deploy-MultipleLocalBox.ps1 -SkipLogin          # Assume you are already logged in
  pwsh ./Deploy-MultipleLocalBox.ps1 -Cleanup -WaitForDeletion

Requires: Azure CLI, Bicep CLI integrated with az (az version >= 2.20+ typically), proper permissions.

Note: The user request included a cluster name spelled 'azlclsuter3'; assumed typo -> using 'azlcluster3'. Adjust in $Scenarios if intentional.
#>
param(
  [string]$TemplateFile = 'main.bicep',
  [string]$ParameterFile = 'main.bicepparam',
  [string]$Location = 'westus2',
  [switch]$Cleanup,                 # Delete resource groups after deployment (or what-if)
  [switch]$WaitForDeletion,         # When used with -Cleanup, waits for each delete to finish
  [switch]$WhatIfOnly,              # Perform what-if instead of actual deployment
  [switch]$SkipLogin,               # Skip az login (use current context)
  [switch]$RemoveLocks              # Attempt to remove resource & RG locks before deletion
)

$ErrorActionPreference = 'Stop'

function Write-Stage {
  param([string]$Message,[string]$Color = 'Cyan')
  Write-Host "==== $Message ====" -ForegroundColor $Color
}

function Remove-ResourceGroupLocks {
  param([string]$ResourceGroup)
  try {
    $locksJson = az lock list --resource-group $ResourceGroup --query "[].{id:id,level:level,name:name}" -o json 2>$null
    if (-not $locksJson -or $locksJson -eq '[]') { return }
    $locks = $locksJson | ConvertFrom-Json
    foreach ($l in $locks) {
      Write-Host "Removing lock '$($l.name)' (level=$($l.level))" -ForegroundColor DarkYellow
      az lock delete --ids $l.id | Out-Null
    }
  } catch {
    Write-Warning "Failed to enumerate/remove locks for $ResourceGroup: $($_.Exception.Message)"
  }
}

if (-not $SkipLogin) {
  Write-Stage 'Logging into Azure (device code may appear)'
  az login --tenant dcea112b-ec40-4856-b620-d8f34929a0e3 | Out-Null
}

# Define deployment scenarios
$Scenarios = @(
  @{ Rg = 'azlrg1'; Cluster = 'azlcluster1'; Mode = 'none'     },
  @{ Rg = 'azlrg2'; Cluster = 'azlcluster2'; Mode = 'validate' },
  @{ Rg = 'azlrg3'; Cluster = 'azlcluster3'; Mode = 'full'     }
)

Write-Stage "Starting scenarios (WhatIf=$WhatIfOnly, Cleanup=$Cleanup)"

foreach ($s in $Scenarios) {
  $rg  = $s.Rg
  $cluster = $s.Cluster
  $mode = $s.Mode
  $deploymentName = "localbox-$mode"

  Write-Stage "Scenario: RG=$rg Cluster=$cluster Mode=$mode" 'Yellow'

  Write-Host "Creating/ensuring resource group $rg in $Location" -ForegroundColor Green
  az group create --name $rg --location $Location | Out-Null

  if ($WhatIfOnly) {
    Write-Host "Running what-if for $deploymentName" -ForegroundColor Magenta
    az deployment group what-if -g $rg -n $deploymentName -f $TemplateFile -p $ParameterFile clusterName=$cluster clusterDeploymentMode=$mode
  } else {
    Write-Host "Deploying (incremental) $deploymentName" -ForegroundColor Green
    az deployment group create -g $rg -n $deploymentName -f $TemplateFile -p $ParameterFile clusterName=$cluster clusterDeploymentMode=$mode
  }

  if ($Cleanup) {
    if ($RemoveLocks) {
      Write-Host "Checking & removing locks in $rg (if any)" -ForegroundColor DarkCyan
      Remove-ResourceGroupLocks -ResourceGroup $rg
    }
    Write-Host "Deleting resource group $rg" -ForegroundColor Red
    $deleteArgs = @('group','delete','--name',$rg,'--yes')
    if (-not $WaitForDeletion) { $deleteArgs += '--no-wait' }
    az @deleteArgs
  }
}

Write-Stage 'All scenarios processed'

if ($Cleanup -and -not $WaitForDeletion) {
  Write-Host 'Deletes running asynchronously (no-wait). Use: az group list -o table to monitor.' -ForegroundColor DarkGray
}

Write-Host 'Done.' -ForegroundColor Cyan
