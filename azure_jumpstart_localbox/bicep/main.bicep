@description('Azure AD tenant id for your service principal')
param tenantId string

@description('Azure AD object id for your Microsoft.AzureStackHCI resource provider')
param spnProviderId string

@description('Username for Windows account')
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string = 'LocalBox-Workspace'

@description('Azure Local cluster name (used inside LocalBox configuration).')
param clusterName string = 'localboxcluster'

@description('Public DNS to use for the domain')
param natDNS string = '8.8.8.8'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Location to deploy resources (except Azure Local cluster resource)')
param location string = resourceGroup().location

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Cluster deployment mode: none = skip cluster deployment, validate = run validation only, full = validate then deploy cluster (and optional upgrade).')
@allowed([
  'none'
  'validate'
  'full'
])
param clusterDeploymentMode string = 'validate'

@description('Choice to enable automatic upgrade of Azure Local cluster resource after the client VM deployment is complete. Only applicable when clusterDeploymentMode = full. Default is false.')
param autoUpgradeClusterResource bool = false

@description('Enable automatic logon into LocalBox Virtual Machine')
param vmAutologon bool = true

@description('Name of the NAT Gateway')
param natGatewayName string = 'LocalBox-NatGateway'

@description('The size of the Virtual Machine')
@allowed([
  'Standard_E32s_v5'
  'Standard_E32s_v6'
])
param vmSize string = 'Standard_E32s_v6'

@description('Option to enable spot pricing for the LocalBox Client VM')
param enableAzureSpotPricing bool = false

@description('Setting this parameter to `true` will add the `CostControl` and `SecurityControl` tags to the provisioned resources. These tags are applicable to ONLY Microsoft-internal Azure lab tenants and designed for managing automated governance processes related to cost optimization and security controls')
param governResourceTags bool = true

@description('Tags to be added to all resources')

param tags object = {
  Project: 'jumpstart_LocalBox'
}

@description('Region to register Azure Local instance in. This is the region where the Azure Local instance resources will be created. The region must be one of the supported Azure Local regions.')
@allowed([
  'australiaeast'
  'southcentralus'
  'eastus'
  'westeurope'
  'southeastasia'
  'canadacentral'
  'japaneast'
  'centralindia'
])
param azureLocalInstanceLocation string = 'australiaeast'

// if governResourceTags is true, add the following tags
var resourceTags = governResourceTags ? union(tags, {
    CostControl: 'Ignore'
    SecurityControl: 'Ignore'
}) : tags

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azl-benchmark-deploy/${githubBranch}/azure_jumpstart_localbox/'
var customerUsageAttributionDeploymentName = 'feada075-1961-4b99-829f-fa3828068933'

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
    resourceTags: resourceTags
  }
}

module networkDeployment 'network/network.bicep' = {
  name: 'networkDeployment'
  params: {
    deployBastion: deployBastion
    location: location
    resourceTags: resourceTags
    natGatewayName: natGatewayName
  }
}

module storageAccountDeployment 'mgmt/storageAccount.bicep' = {
  name: 'stagingStorageAccountDeployment'
  params: {
    location: azureLocalInstanceLocation
    resourceTags: resourceTags
  }
}

module hostDeployment 'host/host.bicep' = {
  name: 'hostVmDeployment'
  params: {
    vmSize: vmSize
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    tenantId: tenantId
    spnProviderId: spnProviderId
    workspaceName: logAnalyticsWorkspaceName
    stagingStorageAccountName: storageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    subnetId: networkDeployment.outputs.subnetId
    deployBastion: deployBastion
    natDNS: natDNS
    location: location
    rdpPort: rdpPort
    clusterDeploymentMode: clusterDeploymentMode
    autoUpgradeClusterResource: autoUpgradeClusterResource
    vmAutologon: vmAutologon
    resourceTags: resourceTags
    enableAzureSpotPricing: enableAzureSpotPricing
    azureLocalInstanceLocation: azureLocalInstanceLocation
    clusterName: clusterName
  }
}

module customerUsageAttribution 'mgmt/customerUsageAttribution.bicep' = {
  name: 'pid-${customerUsageAttributionDeploymentName}'
  params: {
  }
}
