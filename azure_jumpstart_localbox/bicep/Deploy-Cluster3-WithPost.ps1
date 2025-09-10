#requires -Version 7.0

<#
.SYNOPSIS
Deploys LocalBox cluster 3, waits for readiness, then runs logical network + VM image setup.

.PARAMETER SkipDeploy
Skips the initial cluster deployment (useful if it's already running or finished).

.PARAMETER InitialDelayMinutes
How long to wait before starting readiness polling (default 120).

.PARAMETER MaxWaitMinutes
Hard timeout for polling window after the initial delay (default 240).

.PARAMETER PollIntervalMinutes
Polling cadence (default 5).

.PARAMETER ResourceGroup
Resource group containing cluster resources (default azlrg3).

.PARAMETER ClusterName
Cluster 3 name (default azlcluster3).

.PARAMETER LogPath
Optional path to append log output.

.PARAMETER DryRun
Show what would run without executing subordinate scripts.

.NOTES
Assumes az CLI is installed and scripts are in same bicep directory.
#>

[CmdletBinding()]
param(
  [switch]$SkipDeploy,
  [int]$InitialDelayMinutes = 240,
  [int]$MaxWaitMinutes = 480,
  [int]$PollIntervalMinutes = 10,
  [string]$ResourceGroup = 'azlrg4',      
  [string]$ClusterName  = 'azlcluster4',  
  [string]$LogPath,
  [switch]$DryRun
)
# (Optional) dot-source shared vars early (not required but keeps consistency)
. "$PSScriptRoot\LocalBox.Vars.ps1" -ResourceGroup $ResourceGroup -ClusterName $ClusterName

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $ts = (Get-Date).ToString('s')
  $line = "[$ts][$Level] $Message"
  Write-Host $line
  if ($LogPath) { Add-Content -Path $LogPath -Value $line }
}

Write-Log "Starting orchestrator for cluster '$ClusterName' (RG: $ResourceGroup)."

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$deployScript = Join-Path $scriptRoot 'Deploy-MultipleLocalBox.ps1'
$logicalNetScript = Join-Path $scriptRoot 'Create-LogicalNetwork.ps1'
$vmImageScript = Join-Path $scriptRoot 'Create-VMImage.ps1'

foreach ($p in @($deployScript,$logicalNetScript,$vmImageScript)) {
  if (-not (Test-Path $p)) {
    Write-Log "Required script missing: $p" 'ERROR'
    exit 20
  }
}

if (-not $SkipDeploy) {
  Write-Log "Invoking cluster deployment script for ONLY cluster 3."
  if ($DryRun) {
    Write-Log "[DryRun] Would run: & '$deployScript' -ClusterNames @('$ClusterName')" 'DRYRUN'
  } else {
    try {
      # Adjust parameter name below if actual script uses different param (e.g., -Clusters, -Names, etc.)
      & $deployScript -ClusterNames @($ClusterName)
      Write-Log "Deployment script invoked."
    } catch {
      Write-Log "Deployment script failed: $($_.Exception.Message)" 'ERROR'
      exit 30
    }
  }
} else {
  Write-Log "SkipDeploy specified; assuming deployment already in progress or done."
}

if ($InitialDelayMinutes -gt 0) {
  Write-Log "Initial delay of $InitialDelayMinutes minutes before polling."
  if ($DryRun) {
    Write-Log "[DryRun] Would sleep $InitialDelayMinutes minutes." 'DRYRUN'
  } else {
    Start-Sleep -Seconds ($InitialDelayMinutes * 60)
  }
}

$deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
$storagePathId = $null
$pollIndex = 0

function Test-ClusterReady {
  param([string]$Rg)
  try {
    $sp = az stack-hci-vm storagepath list --resource-group $Rg --query "[?starts_with(name, 'UserStorage2-')].id | [0]" -o tsv 2>$null
    if ($sp -and $sp.Trim()) {
      return $sp.Trim()
    }
  } catch {
    # swallow transient errors
  }
  return $null
}

Write-Log "Beginning readiness polling window (max $MaxWaitMinutes minutes)."

while (-not $storagePathId) {
  $pollIndex++
  $storagePathId = Test-ClusterReady -Rg $ResourceGroup
  if ($storagePathId) {
    Write-Log "Cluster readiness signal detected (storage path: $storagePathId)."
    break
  }

  if ((Get-Date) -gt $deadline) {
    Write-Log "Timeout exceeded; cluster not ready within polling window." 'ERROR'
    exit 40
  }

  Write-Log "Poll #${pollIndex}: not ready yet. Waiting ${PollIntervalMinutes} min..."
  if ($DryRun) {
    Write-Log "[DryRun] Would sleep $PollIntervalMinutes minutes." 'DRYRUN'
    if ($pollIndex -ge 2) {
      Write-Log "[DryRun] Stopping early after two dry-run polls."
      break
    }
  } else {
    Start-Sleep -Seconds ($PollIntervalMinutes * 60)
  }
}

if (-not $storagePathId -and $DryRun) {
  Write-Log "[DryRun] Proceeding to post steps hypothetically."
}

# Post Step 1: Logical Network
Write-Log "Running logical network script."
if ($DryRun) {
  Write-Log "[DryRun] Would run: & '$logicalNetScript'" 'DRYRUN'
} else {
  try {
    & $logicalNetScript
    Write-Log "Logical network script completed."
  } catch {
    Write-Log "Logical network script failed: $($_.Exception.Message)" 'ERROR'
    exit 50
  }
}

# Post Step 2: VM Image
Write-Log "Running VM image script."
if ($DryRun) {
  Write-Log "[DryRun] Would run: & '$vmImageScript'" 'DRYRUN'
} else {
  try {
    & $vmImageScript
    Write-Log "VM image creation script completed."
  } catch {
    Write-Log "VM image script failed: $($_.Exception.Message)" 'ERROR'
    exit 60
  }
}

Write-Log "All steps complete successfully." 'SUCCESS'
exit 0