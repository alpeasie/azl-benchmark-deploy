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
$location = "East US"
$switchName = '"ConvergedSwitch(compute_management)"'
$lnetName = "azlcl3-lnet1"
$addressPrefixes = "192.168.1.0/24"
$gateway = "192.168.1.1"
$ipPoolStart = "192.168.1.15"
$ipPoolEnd = "192.168.1.253"
$dnsServers = "192.168.1.254"
$vlanid = 0
$customLocationId = "/subscriptions/fbacedb7-2b65-412b-8b80-f8288b6d7b12/resourceGroups/azlrg3/providers/Microsoft.ExtendedLocation/customLocations/jumpstart"

az stack-hci-vm network lnet create `
    --resource-group $ResourceGroup `
    --custom-location $customLocationId `
    --location $location `
    --name $lnetName `
    --vm-switch-name $switchName `
    --ip-allocation-method "Static" `
    --address-prefixes $addressPrefixes `
    --gateway $gateway `
    --dns-servers $dnsServers `
    --vlan $vlanid `
    --ip-pool-start $ipPoolStart `
    --ip-pool-end $ipPoolEnd


Write-Host "Created Logical Network: $lnetName"