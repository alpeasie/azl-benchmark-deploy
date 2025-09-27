#requires -Version 7.0
<#!
.SYNOPSIS
  Creates (or reuses) an Entra ID security group and assigns RBAC roles:
  - Contributor at the subscription scope
  - Owner on hardcoded resource groups azlrg1, azlrg2, azlrg3

.DESCRIPTION
  Loads TenantId and SubscriptionId from LocalBoxSecrets.psd1 via LocalBox.Secrets.ps1 (same folder).
  Optionally allows overriding SubscriptionId via parameter. Idempotent: will not duplicate group or
  role assignments if they already exist. Uses Azure CLI (az) just like existing LocalBox scripts.

.PARAMETER GroupDisplayName
  Display name of the Entra ID security group to create / reuse.

.PARAMETER MailNickname
  Mail nickname (alias) for the group. If omitted a sanitized version of GroupDisplayName is used.

.PARAMETER SubscriptionId
  Optional override. If omitted, value from LocalBoxSecrets.psd1 is used.

.PARAMETER ResourceGroups
  Resource groups to receive Owner role assignments (defaults to azlrg1, azlrg2, azlrg3).

.PARAMETER SkipSubscriptionContributor
  If specified, skips assigning Contributor at the subscription scope.

.EXAMPLE
  pwsh ./New-LocalBoxSecurityGroup.ps1 -GroupDisplayName "LocalBox Operators"

.EXAMPLE
  pwsh ./New-LocalBoxSecurityGroup.ps1 -GroupDisplayName "LBX Team" -ResourceGroups azlrg1,azlrg5 -Verbose

.NOTES
  Requires: Azure CLI logged-in user with rights to create groups + assign RBAC.
!#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][string]$GroupDisplayName,
  [string]$MailNickname,
  [string]$SubscriptionId,
  [string[]]$ResourceGroups = @('azlrg1','azlrg2','azlrg3'),
  [switch]$SkipSubscriptionContributor
)

$ErrorActionPreference = 'Stop'

function Write-Stage {
  param([string]$Message,[string]$Color='Cyan')
  Write-Host "==== $Message ====" -ForegroundColor $Color
}

# Load secrets (TenantId, SubscriptionId) from sibling secrets helper
. (Join-Path $PSScriptRoot 'LocalBox.Secrets.ps1')
$TenantId = $LocalBoxSecrets.TenantId
if (-not $SubscriptionId) { $SubscriptionId = $LocalBoxSecrets.SubscriptionId }
if (-not $TenantId -or -not $SubscriptionId) { throw 'TenantId and SubscriptionId are required.' }

Write-Stage "Using Tenant=$TenantId Subscription=$SubscriptionId" 'DarkCyan'

# Ensure Azure CLI context aligns (pattern similar to Deploy-MultipleLocalBox)
$ctx = az account show --only-show-errors 2>$null | ConvertFrom-Json
if (-not $ctx -or $ctx.tenantId -ne $TenantId -or $ctx.id -ne $SubscriptionId) {
  Write-Host 'Aligning Azure CLI context...' -ForegroundColor DarkGray
  az login --tenant $TenantId --only-show-errors | Out-Null
  az account set --subscription $SubscriptionId | Out-Null
  $ctx = az account show --only-show-errors | ConvertFrom-Json
}
if ($ctx.tenantId -ne $TenantId -or $ctx.id -ne $SubscriptionId) {
  throw "Azure context mismatch after login. tenant=$($ctx.tenantId) sub=$($ctx.id)"
}

# Derive MailNickname if not provided
if (-not $MailNickname) {
  $MailNickname = ($GroupDisplayName -replace '[^a-zA-Z0-9]','').ToLower()
  if (-not $MailNickname) { throw 'Unable to derive MailNickname (provide -MailNickname explicitly).' }
}

Write-Stage "Group: $GroupDisplayName (alias: $MailNickname)" 'Yellow'

# Locate existing group (exact display name)
$existingGroupId = az ad group list --display-name $GroupDisplayName --query "[0].id" -o tsv 2>$null
if ($existingGroupId) {
  Write-Host "Group already exists. Id=$existingGroupId" -ForegroundColor DarkGray
  $groupId = $existingGroupId
} else {
  if ($PSCmdlet.ShouldProcess("Group '$GroupDisplayName'","Create")) {
    Write-Host 'Creating group...' -ForegroundColor Green
    $grpJson = az ad group create --display-name $GroupDisplayName --mail-nickname $MailNickname -o json
    $groupId = ($grpJson | ConvertFrom-Json).id
    if (-not $groupId) { throw 'Failed to create group (no id returned).' }
    Write-Host "Created group Id=$groupId" -ForegroundColor Green
  }
}

function Add-RoleAssignmentIfMissing {
  param(
    [Parameter(Mandatory)][string]$RoleName,
    [Parameter(Mandatory)][string]$Scope
  )
  $exists = az role assignment list --assignee-object-id $groupId --scope $Scope --query "[?roleDefinitionName=='$RoleName'] | length(@)" -o tsv 2>$null
  if ($exists -and $exists -gt 0) {
    Write-Host "$RoleName already assigned on $Scope" -ForegroundColor DarkGray
    return
  }
  Write-Host "Assigning $RoleName on $Scope" -ForegroundColor Green
  az role assignment create --assignee-object-id $groupId --assignee-principal-type Group --role $RoleName --scope $Scope 1>$null
}

# Subscription Contributor (unless skipped)
if (-not $SkipSubscriptionContributor) {
  Add-RoleAssignmentIfMissing -RoleName 'Contributor' -Scope "/subscriptions/$SubscriptionId"
} else {
  Write-Host 'Skipping Contributor assignment at subscription scope.' -ForegroundColor DarkGray
}

# Owner on each requested resource group
foreach ($rg in $ResourceGroups) {
  if (-not $rg) { continue }
  Add-RoleAssignmentIfMissing -RoleName 'Owner' -Scope "/subscriptions/$SubscriptionId/resourceGroups/$rg"
}

Write-Stage 'Complete' 'Green'
Write-Host "GroupId: $groupId" -ForegroundColor Cyan
