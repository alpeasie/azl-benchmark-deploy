#requires -Version 7.0
param(
  [string]$ResourceGroup,
  [string]$ClusterName
)

$ErrorActionPreference = 'Stop'

# Dot-source shared vars with explicit values (falls back to env/defaults inside LocalBox.Vars.ps1)
. "$PSScriptRoot\LocalBox.Vars.ps1" -ResourceGroup $ResourceGroup -ClusterName $ClusterName -EnsureLogin
$ctx = $Global:LocalBoxContext
$ResourceGroup = $ctx.ResourceGroup
$customLocationId = $ctx.CustomLocationId

# remove any commented hard-coded /subscriptions/.../azlrg3 string to avoid confusion
# (previously: $customLocationId = "/subscriptions/.../resourceGroups/azlrg3/...")

Write-Host "Using RG=$($ctx.ResourceGroup) CustomLocationId=$($ctx.CustomLocationId)"

$location = "East US"
$switchName = '"ConvergedSwitch(compute_management)"'
$lnetName = "$($ctx.ClusterName)-lnet"  
$addressPrefixes = "192.168.1.0/24"
$gateway = "192.168.1.1"
$ipPoolStart = "192.168.1.20"
$ipPoolEnd = "192.168.1.253"
$dnsServers = "192.168.1.254"
$vlanid = 0

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