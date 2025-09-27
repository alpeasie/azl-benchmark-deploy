# filepath: c:\Users\alpease\azbenchmark\localbox-custom\azure_jumpstart_localbox\artifacts\PowerShell\Test-RemoveFabricIPv6.ps1
# Minimal test for removing IPv6 from FABRIC interfaces on node VMs

# Elevate if needed
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $script = $PSCommandPath
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$script`""
    exit
}

# Locate config (adjust if stored elsewhere)
$configCandidates = @(
    Join-Path $PSScriptRoot 'LocalBox-Config.psd1'
    Join-Path $PSScriptRoot '..\LocalBox-Config.psd1'
    'C:\LocalBox\LocalBox-Config.psd1'
) | Where-Object { Test-Path $_ }

if (-not $configCandidates) { throw "LocalBox-Config.psd1 not found." }
$cfgPath = $configCandidates[0]
$LocalBoxConfig = Import-PowerShellDataFile -Path $cfgPath

# Build local Administrator credential from config password
$localCred = New-Object pscredential 'Administrator', (ConvertTo-SecureString $LocalBoxConfig.SDNAdminPassword -AsPlainText -Force)

# Import Hyper-V (needed for Get-VM / Invoke-Command -VMName)
Import-Module Hyper-V

Write-Host "Testing IPv6 removal on FABRIC adapters..." -ForegroundColor Green

foreach ($node in $LocalBoxConfig.NodeHostConfig) {
    $name = $node.Hostname
    Write-Host "VM: $name" -ForegroundColor Cyan
    $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
    if (-not $vm) { Write-Host "  Skipping (VM not found)" -ForegroundColor Yellow; continue }

    # Disable automatic checkpoints (quietly)
    Set-VM -Name $name -AutomaticCheckpointsEnabled $false -ErrorAction SilentlyContinue

    # Attempt IPv6 removal
    Invoke-Command -VMName $name -Credential $localCred -ScriptBlock {
        try {
            Remove-NetIPAddress -InterfaceAlias 'FABRIC' -AddressFamily IPv6 -Confirm:$false -ErrorAction Stop
            Write-Host "  IPv6 removed" -ForegroundColor Green
        } catch {
            Write-Host "  No IPv6 removed (none present or already gone)" -ForegroundColor DarkGray
        }
    } -ErrorAction SilentlyContinue
}

Write-Host "Done." -ForegroundColor Green