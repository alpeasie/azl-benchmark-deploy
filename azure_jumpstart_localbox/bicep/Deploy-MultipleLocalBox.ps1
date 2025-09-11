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




.SCENARIOS
  Scenario 1: RG=azlrg1  Cluster=azlcluster1  Mode=none
  Scenario 2: RG=azlrg2  Cluster=azlcluster2  Mode=validate
  Scenario 3: RG=azlrg3  Cluster=azlcluster3  Mode=full (long-running; post actions auto-enabled unless explicitly disabled)

.PARAMETERS (most common)
  -Scenario 1|2|3|all   Select which scenario(s) to deploy (default: all)
  -ResourceGroupOverride <name>  Override RG (only when a single scenario selected)
  -ClusterNameOverride  <name>   Override cluster name (only single scenario)
  -PostDeploy                     Run post actions (auto ON for scenario 3 single-run unless you pass -PostDeploy:$false)
  -SkipDeploy                     Skip main deployment; run only post actions (scenario 3 case: resume after long provisioning)
  -InitialDelayMinutes <int>      Wait before polling readiness (defaults sized for scenario 3)
  -MaxWaitMinutes <int>           Max polling window after initial delay
  -PollIntervalMinutes <int>      Poll frequency (minutes)
  -WhatIfOnly                     Perform what-if instead of actual deployment
  -Cleanup                        Delete resource group(s) after deployment/what-if
  -WaitForDeletion                Wait for RG deletions to finish
  -RemoveLocks                    Remove resource locks prior to deletion
  -SkipLogin                      Assume current az context is already correct

.NOTES ON VARIABLE FLOW
  Tenant / Subscription are set inline here (easy to see & change if ever needed).
  Scenario defaults (RG + Cluster + Mode) are defined in the $AllScenarios array.
  Overrides apply only when exactly ONE scenario is selected.
  Bicep parameters clusterName + clusterDeploymentMode are passed directly on the az deployment command.
  Post actions call: Create-LogicalNetwork.ps1 and Create-VMImage.ps1 (which themselves use LocalBox.Vars.ps1 / $LocalBoxContext).

.POST DEPLOY (SCENARIO 3)
  Auto-enabled for a single scenario 3 run unless you explicitly disable via: -PostDeploy:$false
  Includes:
    1. Optional initial delay (provisioning buffer for large cluster deploy)
    2. Poll readiness (looks for storage path prefix UserStorage2-)
    3. Runs logical network + VM image scripts
  Disable: -PostDeploy:$false
  Run later only: -Scenario 3 -SkipDeploy -PostDeploy (plus overrides if used originally)

.OVERRIDES EXAMPLES
  Scenario 3, one-off new names with auto post deploy:
    pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 3 -ResourceGroupOverride azlrg6 -ClusterNameOverride azlcluster6
  Same but suppress post actions:
    pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 3 -ResourceGroupOverride azlrg4 -ClusterNameOverride azlcluster4 -PostDeploy:$false
  Resume post actions later (cluster already provisioning/deployed):
    pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 3 -ResourceGroupOverride azlrg4 -ClusterNameOverride azlcluster4 -SkipDeploy -PostDeploy

.GENERAL USAGE
  Deploy all (no post actions for 1/2):
    pwsh ./Deploy-MultipleLocalBox.ps1
  Deploy scenario 2 only:
    pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 2
  What-if scenario 1:
    pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 1 -WhatIfOnly
  Clean up after scenario 2 run (remove locks & wait):
    pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 2 -Cleanup -RemoveLocks -WaitForDeletion

.CLEANUP
  -Cleanup deletes selected scenario RG(s) after deployment/what-if.
  -RemoveLocks helps if RG has delete/update locks.
  -WaitForDeletion blocks until deletion completes; else delete is async.

.RETRY / RERUN SAFE PRACTICES
  - If post actions partially succeeded, you can rerun with -Scenario 3 -SkipDeploy -PostDeploy.
  - If image or logical network already exists, scripts may currently error; add existence checks if you need idempotent skips.

.EXTENSIONS (OPTIONAL IDEAS)
  Add a -ForcePost to recreate post resources.
  Add existence checks to skip already-created logical network or image.
  Add a delete-only script if teardown patterns become more complex.

.EXAMPLES QUICK COPY
  # Default all:
  pwsh ./Deploy-MultipleLocalBox.ps1
  # Scenario 3 (auto post actions):
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 3
  # Scenario 3 custom names + post:
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 1 -ResourceGroupOverride azlrg11 -ClusterNameOverride azlcluster11
  # Scenario 3 custom names, skip post:
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 3 -ResourceGroupOverride azlrg31 -ClusterNameOverride azlcluster31 -PostDeploy:$false
  # Post-only after deploy in progress:
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 3 -SkipDeploy -PostDeploy
  # What-if only:
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 2 -WhatIfOnly
  # Delete after run:
  pwsh ./Deploy-MultipleLocalBox.ps1 -Scenario 1 -Cleanup -WaitForDeletion
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
  [int]$InitialDelayMinutes = 150,     # Delay before polling (set >0 only for long provisioning, e.g. scenario 3)
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

# Filter based on selection (force array so single result still has Count = 1)
if ($Scenario -eq 'all') {
  $Selected = @($AllScenarios)
} else {
  $Selected = @($AllScenarios | Where-Object { $_.Id -eq $Scenario })
}

if (-not $Selected -or $Selected.Count -eq 0) {
  Write-Host "No scenarios selected (parameter: $Scenario)" -ForegroundColor Red
  exit 1
}

# Apply overrides only when exactly one scenario selected
if ($Selected.Count -eq 1 -and ($ResourceGroupOverride -or $ClusterNameOverride)) {
  if ($ResourceGroupOverride) { $Selected[0].Rg = $ResourceGroupOverride }
  if ($ClusterNameOverride)  { $Selected[0].Cluster = $ClusterNameOverride }
  Write-Host "Applied overrides: RG=$($Selected[0].Rg) Cluster=$($Selected[0].Cluster)" -ForegroundColor DarkCyan
  $env:LOCALBOX_RG = $Selected[0].Rg
  $env:LOCALBOX_CLUSTER = $Selected[0].Cluster
  Write-Host "Runtime env set: LOCALBOX_RG=$($env:LOCALBOX_RG) LOCALBOX_CLUSTER=$($env:LOCALBOX_CLUSTER)" -ForegroundColor DarkCyan
}

# Debug (optional)
Write-Host "DEBUG Bound params: $($PSBoundParameters.Keys -join ', ')" -ForegroundColor DarkGray
Write-Host "DEBUG Override values: RGOverride='$ResourceGroupOverride' ClusterOverride='$ClusterNameOverride'" -ForegroundColor DarkGray

Write-Stage "Selected scenario(s): $((($Selected | ForEach-Object { $_.Id }) -join ', ')) (WhatIf=$WhatIfOnly Cleanup=$Cleanup)"

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
      -f $ResolvedTemplate.Path --parameters @$($ResolvedParams.Path) `
      clusterName=$cluster clusterDeploymentMode=$mode
  } else {
    Write-Host "Deploying: $deployName" -ForegroundColor Green
    az deployment group create `
      -g $rg -n $deployName `
      -f $ResolvedTemplate.Path --parameters @$($ResolvedParams.Path) `
      clusterName=$cluster clusterDeploymentMode=$mode; if ($LASTEXITCODE -ne 0) { Write-Host "Single retry after transient failure..." -ForegroundColor Yellow; Start-Sleep 45; az deployment group create -g $rg -n $deployName -f $ResolvedTemplate.Path --parameters @$($ResolvedParams.Path) clusterName=$cluster clusterDeploymentMode=$mode }
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

  # propagate env again (defensive)
  $env:LOCALBOX_RG = $ResourceGroup
  $env:LOCALBOX_CLUSTER = $ClusterName

  Write-Stage "Post: Logical Network" 'Green'
  # Call post scripts with explicit parameters so they don't rely solely on env/defaults
  & $logicalNetScript -ResourceGroup $ResourceGroup -ClusterName $ClusterName

  Write-Stage "Post: VM Image" 'Green'
  & $vmImageScript -ResourceGroup $ResourceGroup -ClusterName $ClusterName
}

foreach ($s in $Selected) {
  # ensure env is set per-iteration so every helper sees the right rg/cluster
  $env:LOCALBOX_RG = $s.Rg
  $env:LOCALBOX_CLUSTER = $s.Cluster
  Write-Host "Using runtime env for scenario $($s.Id): LOCALBOX_RG=$($env:LOCALBOX_RG) LOCALBOX_CLUSTER=$($env:LOCALBOX_CLUSTER)" -ForegroundColor DarkCyan

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