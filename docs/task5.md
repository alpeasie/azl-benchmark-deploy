---
title: Task 5 – Optimization & Cleanup
---

## Objective
Optimize environment or remove resources to control cost.

## Steps
1. Tag resources (if governance disabled initially):
   ```powershell
   az tag update --operation Merge --resource-id <resourceId> --tags CostCenter=Lab Owner=Me
   ```
2. Optional upgrade path:
   ```powershell
   # Trigger upgrade if not auto-run
   pwsh ./artifacts/PowerShell/Update-AzLocalCluster.ps1
   ```
3. Cleanup (destructive):
   ```powershell
   az group delete -n <resourceGroup> --yes --no-wait
   ```
4. Verify deletion progress:
   ```powershell
   az group list -o table
   ```

## Success Criteria
- Unneeded resources deleted OR optimized.
- Documentation updated with lessons learned (add to repo PRs).

Return: [Instructions](index.md)
