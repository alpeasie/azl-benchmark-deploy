---
title: Task 3 – Post-Deploy Configuration
---

## Objective
Perform logical network and VM image setup after the base deployment completes.

## Steps
1. Resume post actions if skipped earlier:
   ```powershell
   pwsh ./bicep/Deploy-MultipleLocalBox.ps1 -Scenario 3 -SkipDeploy -PostDeploy -ResourceGroupOverride <rg> -ClusterNameOverride <cluster> -InitialDelayMinutes 0
   ```
2. Create logical network (direct run):
   ```powershell
   pwsh ./bicep/Create-LogicalNetwork.ps1 -ResourceGroup <rg> -ClusterName <cluster>
   ```
3. Create VM image:
   ```powershell
   pwsh ./bicep/Create-VMImage.ps1 -ResourceGroup <rg> -ClusterName <cluster>
   ```
4. Verify resources:
   ```powershell
   az stack-hci-vm network lnet list -g <rg> -o table
   az stack-hci-vm image list -g <rg> -o table
   ```

## Success Criteria
- Logical network present.
- VM image present and usable.

Next: [Task 4](task4.md)
