---
title: Task 1 – Environment & Prerequisites
---

## Objective
Prepare your Azure subscription, local tooling, and baseline configuration for Azure Local benchmarking.

## Steps
1. Verify Azure CLI login:
   ```powershell
   az account show --output table
   ```
2. Register required providers (run once per subscription):
   ```powershell
   foreach ($ns in 'Microsoft.AzureStackHCI','Microsoft.HybridCompute','Microsoft.HybridConnectivity','Microsoft.GuestConfiguration','Microsoft.ExtendedLocation','Microsoft.Kubernetes','Microsoft.KubernetesConfiguration') { az provider register -n $ns }
   ```
3. Confirm registration state:
   ```powershell
   az provider show -n Microsoft.AzureStackHCI --query registrationState -o tsv
   ```
4. Clone repo and inspect `bicep/` templates.
5. Adjust `main.bicepparam` as needed (do not commit secrets).

## Success Criteria
- All providers show `Registered`.
- You have a clean working local clone and updated param file.

Next: [Task 2](task2.md)
