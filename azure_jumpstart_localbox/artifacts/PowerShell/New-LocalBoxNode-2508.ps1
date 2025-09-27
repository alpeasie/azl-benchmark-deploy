# filepath: c:\Users\alpease\azbenchmark\localbox-custom\azure_jumpstart_localbox\artifacts\PowerShell\New-LocalBoxNode-2508.ps1
Start-Transcript -Path $Env:LocalBoxLogsDir\New-LocalBoxCluster.log
$starttime = Get-Date

# Self-elevate if not running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Host "Not elevated. Relaunching as Administrator..." -ForegroundColor Yellow
    $scriptPath = $PSCommandPath
    $argsList   = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$scriptPath`"")
    # Preserve any original args passed to this script
    if ($args.Count -gt 0) { $argsList += $args }
    Start-Process -FilePath 'pwsh.exe' -ArgumentList $argsList -Verb RunAs
    exit
}

Write-Host "Running as Administrator: Confirmed" -ForegroundColor Green
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Resolve LocalBox config automatically if env var not set
if (-not $Env:LocalBoxConfigFile -or -not (Test-Path $Env:LocalBoxConfigFile)) {
    $candidatePaths = @(
        Join-Path $PSScriptRoot 'LocalBox-Config.psd1'
        Join-Path $PSScriptRoot '..\LocalBox-Config.psd1'
        'C:\LocalBox\LocalBox-Config.psd1'
    ) | ForEach-Object { Resolve-Path -Path $_ -ErrorAction SilentlyContinue } | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
    $resolved = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $resolved) {
        throw "Unable to locate LocalBox-Config.psd1. Checked: $($candidatePaths -join '; ')"
    }
    $Env:LocalBoxConfigFile = $resolved
    Write-Host "Config file resolved to: $Env:LocalBoxConfigFile" -ForegroundColor Cyan
}

$Global:LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile


# Ensure we're in an elevated context
Write-Host "Running as Administrator: Confirmed" -ForegroundColor Green

# Set execution policy for this session (needed for right-click run)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force


# Import Configuration data file
$Global:LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile

#region Main
$HostVMPath = $LocalBoxConfig.HostVMPath
$InternalSwitch = $LocalBoxConfig.InternalSwitch

$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup

Import-Module Hyper-V

# Set credentials
$localCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist "Administrator", (ConvertTo-SecureString $LocalBoxConfig.SDNAdminPassword -AsPlainText -Force)

$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($LocalBoxConfig.SDNDomainFQDN.Split(".")[0]) +"\Administrator"), (ConvertTo-SecureString $LocalBoxConfig.SDNAdminPassword -AsPlainText -Force)

# Enable PSRemoting
Write-Host "[Build cluster - Step 2/11] Preparing Azure VM virtualization host..." -ForegroundColor Green
Write-Host "Enabling PS Remoting on client..."
Enable-PSRemoting
set-item WSMan:localhost\client\trustedhosts -value * -Force
Enable-WSManCredSSP -Role Client -DelegateComputer "*.$($LocalBoxConfig.SDNDomainFQDN)" -Force

<#
$ChildVhd = "V:\VMs\AzL-2508.vhdx" 
$BaseVhd = "V:\VMs\Base\AzL-2508-base.vhdx"
New-VHD -Path $ChildVhd -ParentPath $BaseVhd -Differencing 
#>


<#
$copies = @(
    @{ Source = $LocalBoxConfig.AzLocalVHDXPath; Dest = $azlocalpath; Label = 'AzL-2508'}
)

foreach ($c in $copies) {

    if (-not (Test-Path $c.Source)) { throw "Source VHDX missing: $($c.Source)" }

    $destDir = Split-Path -Path $c.Dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    if (Test-Path $c.Dest) {
        if ( (Get-Item $c.Dest).Length -eq (Get-Item $c.Source).Length ) {
            Write-Host "[$($c.Label)] Destination already present & size matches; skipping copy."
            continue
        } else {
            Write-Host "[$($c.Label)] Existing destination size mismatch; recopying..."
            Remove-Item -Path $c.Dest -Force
        }
    }

    $attempt = 0
    do {
        $attempt++
        try {
            Write-Host "[$($c.Label)] Copy attempt $attempt..."
            Copy-Item -Path $c.Source -Destination $c.Dest -Force
            if ( (Get-Item $c.Source).Length -ne (Get-Item $c.Dest).Length ) {
                throw "Size mismatch after copy."
            }
            Write-Host "[$($c.Label)] Copy successful."
            break
        } catch {
            Write-Warning "[$($c.Label)] Copy failed attempt $($_.Exception.Message)"
            Start-Sleep -Seconds (5 * $attempt)
            if ($attempt -ge 3) { throw "[$($c.Label)] Failed after $attempt attempts." }
        }
    } while ($true)
}
#>


################################################################################
# Create the Virtual Machines
################################################################################


$BaseVHD = "V:\VMs\Base\AzL-2508-base.vhdx"



foreach ($VM in $LocalBoxConfig.NodeHostConfig) {
    $mac = New-AzLocalNodeVM -Name $VM.Hostname -VHDXPath $BaseVHD -VMSwitch $InternalSwitch -LocalBoxConfig $LocalBoxConfig
    Set-AzLocalNodeVhdx -HostName $VM.Hostname -IPAddress $VM.IP -VMMac $mac  -LocalBoxConfig $LocalBoxConfig
}

# Enable vTPM on all node VMs only when clusterDeploymentMode = 'none'
Write-Host "Attempting to enable vTPM on nested node VMs (mode=none)..." -ForegroundColor Green
foreach ($node in $LocalBoxConfig.NodeHostConfig) {
    $name = $node.Hostname
    try {
        $vmObj = Get-VM -Name $name -ErrorAction Stop
        if ($vmObj.Generation -ne 2) {
            Write-Warning "VM $name is not Generation 2; cannot enable vTPM."
            continue
        }

        # Hyper-V uses a key protector; ensure one exists before enabling TPM
        $sec = Get-VMSecurity -VMName $name -ErrorAction Stop
        if (-not $sec.TpmEnabled) {
            Write-Host "Configuring key protector + enabling vTPM on $name..." -ForegroundColor Cyan
            # Use local (unencrypted) key protector – sufficient for lab / nested scenario
            Set-VMKeyProtector -VMName $name -NewLocalKeyProtector -ErrorAction Stop
            Enable-VMTPM -VMName $name -ErrorAction Stop
            Write-Host "vTPM successfully enabled on $name." -ForegroundColor Green
        } else {
            Write-Host "vTPM already enabled on $name (skipping)." -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Failed to enable vTPM on $name : $($_.Exception.Message)"
    }
}



# Start Virtual Machines
Write-Host "[Build cluster - Step 5/11] Starting VMs..." -ForegroundColor Green
foreach ($VM in $LocalBoxConfig.NodeHostConfig) {
    Write-Host "Starting VM: $($VM.Hostname)"
    Start-VM -Name $VM.Hostname
}

#######################################################################################
# Prep the virtualization environment
#######################################################################################
Write-Host "[Build cluster - Step 6/11] Configuring host networking and storage..." -ForegroundColor Green

# Wait for AzSHOSTs to come online
Test-AllVMsAvailable -LocalBoxConfig $LocalBoxConfig -Credential $localCred

Start-Sleep -Seconds 120

# Format and partition data drives
Set-DataDrives -LocalBoxConfig $LocalBoxConfig -Credential $localCred

# Configure networking
Set-NICs -LocalBoxConfig $LocalBoxConfig -Credential $localCred


#######################################################################################
# Provision the router, domain controller, and WAC VMs and join the hosts to the domain
#######################################################################################




# Remove IPv6 address from FABRIC interface for all node VMs
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

$endtime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Host
Write-Host "Successfully prepped LocalBox infrastructure." -ForegroundColor Green
Write-Host "Infrastructure prep time was $($timeSpan.Hours):$($timeSpan.Minutes) (hh:mm)." -ForegroundColor Green

Stop-Transcript

#endregion

