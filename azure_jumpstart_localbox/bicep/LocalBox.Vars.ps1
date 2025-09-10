# Shared LocalBox variable/bootstrap helper

param(
  [string]$ResourceGroup,
  [string]$ClusterName,
  [string]$TenantId = 'dcea112b-ec40-4856-b620-d8f34929a0e3',
  [string]$SubscriptionId = 'fbacedb7-2b65-412b-8b80-f8288b6d7b12',
  [switch]$EnsureLogin
)

# Defaults (scenario 3 defaults remain azlrg3 / azlcluster3; overrides via env or params)
if (-not $ResourceGroup) { $ResourceGroup = $env:LOCALBOX_RG  ; if (-not $ResourceGroup) { $ResourceGroup = 'azlrg3' } }
if (-not $ClusterName)  { $ClusterName  = $env:LOCALBOX_CLUSTER ; if (-not $ClusterName)  { $ClusterName = 'azlcluster3' } }

# Optional login/context alignment
if ($EnsureLogin) {
  $ctx = az account show --only-show-errors 2>$null | ConvertFrom-Json
  if (-not $ctx -or $ctx.tenantId -ne $TenantId -or $ctx.id -ne $SubscriptionId) {
    az login --tenant $TenantId --only-show-errors | Out-Null
    az account set --subscription $SubscriptionId | Out-Null
    $ctx = az account show --only-show-errors | ConvertFrom-Json
  }
  if ($ctx.tenantId -ne $TenantId -or $ctx.id -ne $SubscriptionId) {
    throw "Azure context mismatch. Wanted Tenant=$TenantId Sub=$SubscriptionId Got Tenant=$($ctx.tenantId) Sub=$($ctx.id)"
  }
}

function Get-LocalBoxContext {
  param(
    [string]$ResourceGroup,
    [string]$ClusterName,
    [string]$TenantId,
    [string]$SubscriptionId,
    [string]$CustomLocationName = 'jumpstart'
  )
  $customLocationId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ExtendedLocation/customLocations/$CustomLocationName"
  return @{
    TenantId          = $TenantId
    SubscriptionId    = $SubscriptionId
    ResourceGroup     = $ResourceGroup
    ClusterName       = $ClusterName
    CustomLocationId  = $customLocationId
    CustomLocationName= $CustomLocationName
  }
}

# Export context variable for convenience
$Global:LocalBoxContext = Get-LocalBoxContext -ResourceGroup $ResourceGroup -ClusterName $ClusterName -TenantId $TenantId -SubscriptionId $SubscriptionId