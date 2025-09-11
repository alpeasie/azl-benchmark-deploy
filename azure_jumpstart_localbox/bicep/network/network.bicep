@description('Name of the VNet')
param virtualNetworkName string = 'LocalBox-VNet'

@description('Name of the subnet in the virtual network')
param subnetName string = 'LocalBox-Subnet'

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the NAT Gateway')
param natGatewayName string = 'LocalBox-NatGateway'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'LocalBox-NSG'

@description('Name of the Bastion Network Security Group')
param bastionNetworkSecurityGroupName string = 'LocalBox-Bastion-NSG'

param resourceTags object

var addressPrefix = '172.16.0.0/16'
var subnetAddressPrefix = '172.16.1.0/24'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = '${arcVirtualNetwork.id}/subnets/${bastionSubnetName}'
var bastionName = 'LocalBox-Bastion'
var bastionSubnetIpPrefix = '172.16.3.64/26'
var bastionPublicIpAddressName = '${bastionName}-PIP'

resource arcVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: deployBastion == true ? [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          natGateway: deployBastion ? {
            id: natGateway.id
          } : null
          defaultOutboundAccess: false
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetIpPrefix
          networkSecurityGroup: {
            id: bastionNetworkSecurityGroup.id
          }
        }
      }
    ] : [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          natGateway: deployBastion ? {
            id: natGateway.id
          } : null
          defaultOutboundAccess: false
        }
      }
    ]
  }
 tags: resourceTags
}

resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (deployBastion == true) {
  name: '${natGatewayName}-PIP'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = if (deployBastion == true) {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natGatewayPublicIp.id
      }
    ]
    idleTimeoutInMinutes: 4
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-03-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
    ]
  }
  tags: resourceTags
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-05-01' = if (deployBastion == true) {
  name: bastionNetworkSecurityGroupName
  location: location
  properties: {
    securityRules: [
    ]
  }
  tags: resourceTags
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2021-05-01' = if (deployBastion == true) {
  name: bastionPublicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
  tags: resourceTags
}

resource bastionHost 'Microsoft.Network/bastionHosts@2021-05-01' = if (deployBastion == true) {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          publicIPAddress: {
            id: publicIpAddress.id
          }
          subnet: {
            id: bastionSubnetRef
          }
        }
      }
    ]
  }
  tags: resourceTags
}

output vnetId string = arcVirtualNetwork.id
output subnetId string = arcVirtualNetwork.properties.subnets[0].id
