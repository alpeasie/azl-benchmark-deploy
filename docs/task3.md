
# Task 3: Create a VM on your Azure Local cluster

## Context

You just deployed an Azure Local cluster, now you want to deploy a VM on the cluster.

## Your goal

Use the Azure portal to deploy a Windows Server 2025 VM on the cluster _azlcluster3_ in the resource group _azlrg3_.

**Stop when:** VM deployment runs for ~30 seconds.

## Details

- **General:** You plan to use the VM for testing, not production. You want to manage the cluster’s operating system using Azure.
- **Resource group:** Create the VM in the same RG as the cluster.
- **VM size:** 2 CPUs and 4GBs of RAM.
- **OS:** Windows Server 2025. Use a Windows VHD file that is stored on the cluster at: `C:\ClusterStorage\UserStorage_2`. This image was previously downloaded from the Azure marketplace and stored on your cluster and is accessible in the Azure portal.
- **Storage:** Create a 100GB drive for application data.

### Network

- Connect the VM to Azure using the public internet but don’t open any inbound ports.
- Place the VM on the local network and in the same subnet as your cluster:
  - Local network subnet: 192.168.1.0 / 24
  - Cluster IP: 192.168.1.15
  - Gateway: 192.168.1.1
  - No VLAN



Next: [Task 4](task4.md)
