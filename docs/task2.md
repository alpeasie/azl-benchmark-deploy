---
title: Task 2 – Deployment Workflow
---

## Objective
Deploy the core Azure Local (stack HCI) scenario using the provided Bicep template and orchestration script.

## Steps
1. Run what-if to validate changes:
   ```powershell
   az deployment group what-if -g <resourceGroup> -f bicep/main.bicep -p bicep/main.bicepparam
   ```
2. Create or ensure resource group exists:
   ```powershell
   az group create -n <resourceGroup> -l eastus
   ```
3. Deploy:
   ```powershell
   az deployment group create -g <resourceGroup> -f bicep/main.bicep -p bicep/main.bicepparam
   ```
4. Use multi-scenario script (example):
   ```powershell
   pwsh ./bicep/Deploy-MultipleLocalBox.ps1 -Scenario 3 -ResourceGroupOverride <rg> -ClusterNameOverride <cluster>
   ```

## Success Criteria
- Deployment reports `ProvisioningState: Succeeded`.
- Management VM and node VMs are created.

Next: [Task 3](task3.md)
