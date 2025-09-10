#requires -Version 7.0

<#
Purpose: Deploy one or more LocalBox scenarios (1,2,3, or all) with different
         resource group names, cluster names, and deployment modes, then optionally delete them.

Scenarios mapping:

cd azure_jumpstart_localbox/bicep
resourceGroupName="azlrg2"
location="eastus" 
az login --tenant dcea112b-ec40-4856-b620-d8f34929a0e3 
az group create --name resourceGroupName --location location
az deployment group create -g resourceGroupName -f "main.bicep" -p "main.bicepparam"



 1. azlrg1 / azlcluster1 / none
 2. azlrg2 / azlcluster2 / validate
 3. azlrg3 / azlcluster3 / full

Selection:
  -Scenario 1     # only scenario 1
  -Scenario 2
  -Scenario 3
  -Scenario all   # (default) all three

Examples:
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 2
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 3 -Cleanup -RemoveLocks
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario all -WhatIfOnly

Existing switches still apply to the filtered set.
#>
[CmdletBinding()]
param(
  [string]$TemplateFile = 'main.bicep',
  [string]$ParameterFile = 'main.bicepparam',
  [string]$Location = 'eastus',

  [ValidateSet('1','2','3','all')]
  [string]$Scenario = 'all',          # Which scenario(s) to run

  # Optional overrides for a single scenario run (ignored when -Scenario all selects multiple)
  [string]$ResourceGroupOverride,
  [string]$ClusterNameOverride,

  # Post-deploy orchestration (applies only when exactly one scenario selected)
  [switch]$PostDeploy,                # Enable post actions (logical network + VM image)
  [int]$InitialDelayMinutes = 240,      # Delay before polling (set >0 only for long provisioning, e.g. scenario 3)
  [int]$MaxWaitMinutes = 480,         # Polling window
  [int]$PollIntervalMinutes = 10,     # Poll cadence
  [switch]$SkipDeploy,                # Run only post steps (assumes deploy already done)

  [switch]$Cleanup,                   # Delete resource groups after deployment (or what-if)
  [switch]$WaitForDeletion,           # With -Cleanup, waits for deletions
  [switch]$WhatIfOnly,                # Only run what-if
  [switch]$SkipLogin,                 # Skip az login
  [switch]$RemoveLocks                # Remove locks before deletion
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
    Write-Warning "Failed to enumerate/remove locks for ${ResourceGroup}: $($_.Exception.Message)"
  }
}

# Resolve paths relative to script directory to avoid CWD issues
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResolvedTemplate = Resolve-Path -Path (Join-Path $ScriptRoot $TemplateFile)
$ResolvedParams   = Resolve-Path -Path (Join-Path $ScriptRoot $ParameterFile)

# Test if user is logged into Azure
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


# Full scenario definitions
$AllScenarios = @(
  @{ Id='1'; Rg='azlrg1'; Cluster='azlcluster1'; Mode='none'     },
  @{ Id='2'; Rg='azlrg2'; Cluster='azlcluster2'; Mode='validate' },
  @{ Id='3'; Rg='azlrg3'; Cluster='azlcluster3'; Mode='full'     }
)

# Filter based on selection
$Selected = if ($Scenario -eq 'all') { $AllScenarios } else { $AllScenarios | Where-Object { $_.Id -eq $Scenario } }
if (-not $Selected -or $Selected.Count -eq 0) {
  Write-Host "No scenarios selected (parameter: $Scenario)" -ForegroundColor Red
  exit 1
}

Write-Stage "Selected scenario(s): $($Selected.Id -join ', ') (WhatIf=$WhatIfOnly Cleanup=$Cleanup)"

# Auto-enable post deploy for scenario 3 when it's the only selected scenario and user did not explicitly pass -PostDeploy or -SkipDeploy
if ($Selected.Count -eq 1 -and $Selected[0].Id -eq '3' -and -not $PSBoundParameters.ContainsKey('PostDeploy') -and -not $SkipDeploy) {
  $PostDeploy = $true
  Write-Host "Auto-enabled PostDeploy for scenario 3 (override with -PostDeploy:
  \$false if you want to skip)." -ForegroundColor DarkGray
}

function Invoke-ScenarioDeployment {
  param(
    [Parameter(Mandatory)]$ScenarioObject
  )
  $rg        = $ScenarioObject.Rg
  $cluster   = $ScenarioObject.Cluster
  $mode      = $ScenarioObject.Mode
  $deployName = "localbox-$mode"

  Write-Stage "Scenario $($ScenarioObject.Id): RG=$rg Cluster=$cluster Mode=$mode" 'Yellow'

  Write-Host "Ensuring resource group $rg ($Location)" -ForegroundColor Green
  az group create --name $rg --location $Location | Out-Null

  if ($WhatIfOnly) {
    Write-Host "What-if: $deployName" -ForegroundColor Magenta
    az deployment group what-if `
      -g $rg -n $deployName `
      -f $ResolvedTemplate -p $ResolvedParams `
      clusterName=$cluster clusterDeploymentMode=$mode
  } else {
    Write-Host "Deploying: $deployName" -ForegroundColor Green
    az deployment group create `
      -g $rg -n $deployName `
      -f $ResolvedTemplate -p $ResolvedParams `
      clusterName=$cluster clusterDeploymentMode=$mode
  }

  if ($Cleanup) {
    if ($RemoveLocks) {
      Write-Host "Removing locks (if any) in $rg" -ForegroundColor DarkCyan
      Remove-ResourceGroupLocks -ResourceGroup $rg
    }
    Write-Host "Deleting resource group $rg" -ForegroundColor Red
    $deleteArgs = @('group','delete','--name',$rg,'--yes')
    if (-not $WaitForDeletion) { $deleteArgs += '--no-wait' }
    az @deleteArgs
  }
}

function Test-ClusterReady {
  param([string]$ResourceGroup)
  try {
    $sp = az stack-hci-vm storagepath list --resource-group $ResourceGroup --query "[?starts_with(name, 'UserStorage2-')].id | [0]" -o tsv 2>$null
    if ($sp -and $sp.Trim()) { return $true }
  } catch {}
  return $false
}

function Invoke-PostActions {
  param([string]$ResourceGroup,[string]$ClusterName)
  $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
  $logicalNetScript = Join-Path $scriptRoot 'Create-LogicalNetwork.ps1'
  $vmImageScript    = Join-Path $scriptRoot 'Create-VMImage.ps1'

  Write-Stage "Post: Logical Network" 'Green'
  & $logicalNetScript
  Write-Stage "Post: VM Image" 'Green'
  & $vmImageScript
}

# When only one scenario selected allow overrides
if ($Selected.Count -eq 1 -and ($ResourceGroupOverride -or $ClusterNameOverride)) {
  if ($ResourceGroupOverride) { $Selected[0].Rg = $ResourceGroupOverride }
  if ($ClusterNameOverride)  { $Selected[0].Cluster = $ClusterNameOverride }
  Write-Host "Applied overrides: RG=$($Selected[0].Rg) Cluster=$($Selected[0].Cluster)" -ForegroundColor DarkCyan
}

foreach ($s in $Selected) {
  if (-not $SkipDeploy) {
    Invoke-ScenarioDeployment -ScenarioObject $s
  } else {
    Write-Host "SkipDeploy specified; assuming scenario $($s.Id) already deployed." -ForegroundColor Yellow
  }

  if ($PostDeploy -and $Selected.Count -eq 1 -and $s.Id -eq '3') {
    $rg = $s.Rg; $cluster = $s.Cluster
    Write-Stage "Post-deploy orchestration (RG=$rg Cluster=$cluster)" 'Magenta'
    if ($InitialDelayMinutes -gt 0) {
      Write-Host "Initial delay $InitialDelayMinutes min before polling" -ForegroundColor Gray
      Start-Sleep -Seconds ($InitialDelayMinutes * 60)
    }
    $deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
    $poll = 0
    while (-not (Test-ClusterReady -ResourceGroup $rg)) {
      if ((Get-Date) -gt $deadline) { throw "Timeout: cluster not ready within $MaxWaitMinutes minutes" }
      $poll++
      Write-Host "Poll #$poll not ready; waiting $PollIntervalMinutes min..." -ForegroundColor DarkGray
      Start-Sleep -Seconds ($PollIntervalMinutes * 60)
    }
    Write-Host "Cluster readiness signal detected; running post actions." -ForegroundColor Green
    Invoke-PostActions -ResourceGroup $rg -ClusterName $cluster
  }
}

Write-Stage 'Processing complete'

if ($Cleanup -and -not $WaitForDeletion) {
  Write-Host 'Deletes are async. Monitor with: az group list -o table' -ForegroundColor DarkGray
}

Write-Host 'Done.' -ForegroundColor Cyan