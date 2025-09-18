---
title: Task 4 – Validation & Testing
---

## Objective
Validate the deployed environment functionality and connectivity.

## Steps
1. Check VM states:
   ```powershell
   Get-VM | Select-Object Name, State
   ```
2. Confirm vTPM enabled (scenario 1 minimal nodes):
   ```powershell
   Get-VM | Where Name -like 'AzLHOST*' | ForEach-Object { Get-VMSecurity -VMName $_.Name | Select VMName,TpmEnabled }
   ```
3. Validate storage path creation:
   ```powershell
   az stack-hci-vm storagepath list -g <rg> -o table
   ```
4. (Optional) Run custom tests / scripts.

## Success Criteria
- All target VMs running with expected security features.
- Network & storage resources healthy.

Next: [Task 5](task5.md)
