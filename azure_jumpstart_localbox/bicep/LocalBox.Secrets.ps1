# Centralized secrets loader (TenantId, SubscriptionId)
$secretsPath = Join-Path $PSScriptRoot 'LocalBoxSecrets.psd1'
if (-not (Test-Path $secretsPath)) { throw "Missing secrets file: $secretsPath" }
$LocalBoxSecrets = Import-PowerShellDataFile -Path $secretsPath
if (-not $LocalBoxSecrets.TenantId -or -not $LocalBoxSecrets.SubscriptionId) {
  throw "TenantId and SubscriptionId must both be set in LocalBoxSecrets.psd1"
}
