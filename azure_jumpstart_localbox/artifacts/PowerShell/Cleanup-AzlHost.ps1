[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$VmName = 'azlhost1',
    [switch]$Force,
    [switch]$DeleteSharedBase  # Only if you really want to remove a base disk still referenced by other VMs
)

Write-Host "=== LocalBox single-node cleanup: $VmName ==="

# Basic pre-flight
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    throw "Hyper-V module / role not available. Run on the virtualization host."
}

$vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Warning "VM $VmName not found. Continuing to attempt VHD cleanup."
}

# Gather all disk attachments for target VM
$targetDisks = @()
if ($vm) {
    $targetDisks = Get-VMHardDiskDrive -VMName $VmName | ForEach-Object { $_.Path } | Where-Object { $_ } | Sort-Object -Unique
}

if ($targetDisks.Count -eq 0) {
    Write-Host "No disks discovered directly from VM metadata."
}

# Build inventory of disks used by other VMs to avoid accidental deletion
$otherVmDisks = @{}
Get-VM | Where-Object { $_.Name -ne $VmName } | ForEach-Object {
    Get-VMHardDiskDrive -VMName $_.Name | ForEach-Object {
        if ($_.Path) { $otherVmDisks[$_.Path.ToLowerInvariant()] = $true }
    }
}

function Test-DiskInUseElsewhere {
    param([string]$Path)
    return $otherVmDisks.ContainsKey($Path.ToLowerInvariant())
}

# Optional heuristic: include orphaned differencing disks named for the VM even if not attached (e.g., after partial deletion)
$vmNameLower = $VmName.ToLower()
$hostFolders = @()
# Try to infer root folder(s) from existing disk paths
if ($targetDisks) {
    $hostFolders = $targetDisks | ForEach-Object { Split-Path -Path $_ -Parent } | Sort-Object -Unique
} else {
    # Fallback to common locations (adjust if your config differs)
    $hostFolders = @("C:\ClusterStorage","C:\LocalBox","D:\HyperV","E:\HyperV") | Where-Object { Test-Path $_ }
}
# Scan for stray VHDX files named after VM
$patternDisks = @()
foreach ($f in $hostFolders) {
    Get-ChildItem -Path $f -Recurse -Include *.vhd,*.vhdx -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.ToLower() -like "*$vmNameLower*" } |
        ForEach-Object { if ($targetDisks -notcontains $_.FullName) { $patternDisks += $_.FullName } }
}
if ($patternDisks) {
    Write-Host "Discovered candidate orphaned disks (name pattern):"
    $patternDisks | ForEach-Object { "  $_" }
}

# Merge & de-duplicate disk list
$allCandidateDisks = @($targetDisks + $patternDisks) | Sort-Object -Unique

if ($vm) {
    # Stop VM if running
    if ($vm.State -ne 'Off') {
        if ($PSCmdlet.ShouldProcess($VmName, "Stop-VM")) {
            Stop-VM -Name $VmName -Force -TurnOff:$Force.IsPresent
            $vm | Wait-VM -For Heartbeat -Timeout 5 -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Remove VM (keeps disks unless -Force with Remove-VM? We remove disks manually for safety)
    if ($PSCmdlet.ShouldProcess($VmName, "Remove-VM (configuration only)")) {
        Remove-VM -Name $VmName -Force:$Force.IsPresent -Confirm:$false
        Write-Host "VM $VmName configuration removed."
    }
} else {
    Write-Host "Skipping VM removal (not present)."
}

# Disk deletion phase
$deleted = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

foreach ($disk in $allCandidateDisks) {
    $exists = Test-Path $disk
    if (-not $exists) {
        $skipped.Add("$disk (missing)")
        continue
    }
    $inUseElsewhere = Test-DiskInUseElsewhere -Path $disk
    if ($inUseElsewhere -and -not $DeleteSharedBase.IsPresent) {
        $skipped.Add("$disk (shared by another VM; use -DeleteSharedBase to force)")
        continue
    }

    # Sanity check: ensure not currently attached (e.g., race condition)
    $stillAttached = (Get-VMHardDiskDrive -All | Where-Object { $_.Path -eq $disk }) -ne $null
    if ($stillAttached -and -not $DeleteSharedBase.IsPresent) {
        $skipped.Add("$disk (still attached to a VM)")
        continue
    }

    if ($PSCmdlet.ShouldProcess($disk, "Remove VHD file")) {
        try {
            Remove-Item -Path $disk -Force
            $deleted.Add($disk)
        } catch {
            $skipped.Add("$disk (error: $($_.Exception.Message))")
        }
    }
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Deleted disks:" -ForegroundColor Green
if ($deleted.Count) { $deleted | ForEach-Object { "  $_" } } else { "  (none)" }
Write-Host ""
Write-Host "Skipped disks:" -ForegroundColor Yellow
if ($skipped.Count) { $skipped | ForEach-Object { "  $_" } } else { "  (none)" }

Write-Host ""
Write-Host "Cleanup complete. Use -WhatIf first next time to preview." -ForegroundColor Cyan