#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\LocalBox.Vars.ps1" -EnsureLogin
$ctx = $LocalBoxContext
$ResourceGroup = $ctx.ResourceGroup
$customLocationId = $ctx.CustomLocationId

#$customLocationId = "/subscriptions/fbacedb7-2b65-412b-8b80-f8288b6d7b12/resourceGroups/azlrg3/providers/Microsoft.ExtendedLocation/customLocations/jumpstart"

Write-Host "Using RG=$($ctx.ResourceGroup) CustomLocationId=$($ctx.CustomLocationId)"

$location = "East US"
$switchName = '"ConvergedSwitch(compute_management)"'
$lnetName = "$($ctx.ClusterName)img1"  
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