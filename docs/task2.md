
# Task 2: Deploy a 2-node Azure Local cluster

## Overview

**Context:** You connected two server nodes to the Azure cloud. Now, you want to deploy a 2-node Azure Local cluster.

**Your goal:** Use the Azure portal to deploy an Azure Local cluster using the servers `AzLHOST1` and `AzLHOST2` in the resource group `azlrg2`.

**Stop when:** Azure Local cluster deployment starts.

## Detailed instructions

Use the following details to help you create the cluster. If the instructions do not specify a configuration (like what to name the cluster), choose a name based on your professional opinion and the context provided in the task.

### Azure configuration

- **Resource group:** Create the cluster in the same RG of the servers, `azlrg2`
- **Region:** East US

## Network details 

### Intended Network Adapter Configuration 

| Server name | Adapter Name | IP Address      | VLAN |
|-------------|--------------|-----------------|------|
| AzLHOST1    | FABRIC       | 192.168.1.11    | 0    |
| AzLHOST1    | StorageA     | Auto-assigned   | 711  |
| AzLHOST1    | StorageB     | Auto-assigned   | 712  |
| AzLHOST2    | FABRIC       | 192.168.1.12    | 0    |
| AzLHOST2    | StorageA     | Auto-assigned   | 711  |
| AzLHOST2    | StorageB     | Auto-assigned   | 712  |


### How the cluster is cabeled 



### Cluster network configuration

- Ensure the cluster and workloads are reachable on the local network. Assign the smallest number of IP addresses required.
- Create two subnets for storage traffic using different VLANs. The storage networks should be isolated from the local network.
- Maximize the MTU size for the storage adapters.

### Local network details

- **Subnet:** 192.168.1.0 / 24
- **Default gateway:** 192.168.1.1
- **DNS server:** 192.168.1.254
- **Available IP addresses:** 192.168.1.11 – 192.168.1.200 (except for 192.168.1.20, which is the IP of the machine you’re currently using on the network).

### Cluster network interface details

Each server has 3 network adapters:
- 2 for storage, which are directly connected via ethernet cables.
- 1 for workloads and managing the servers. These are cabled to a network switch.

- **Node1 IP:** 192.168.1.11
- **Node2 IP:** 192.168.1.12

!Cluster Network Diagram

### Active Directory & credentials

- Join the cluster to the domain: `jumpstart.local/hcioudocs`
- OU formatting: `OU=hcioudocs,DC=jumpstart,DC=local`
- Domain creds: `localboxdeployuser/azlTesting321!`
- Local admin creds: `administrator/azlTesting321!`

### Cluster features

- Ensure the cluster follows security best practices for a test cluster but disable bitlocker
- Create multiple cluster shared volumes for workloads


## End of task instructions

- **Stop when:** Azure Local cluster deployment starts. Let me know when you think you're done. 

## Next steps 
1. (Optional): Open the progress animation [prototype](https://www.figma.com/proto/iBO6B6vgjwlEzgv7p10qFi/AzL-Benchmark-Prototypes?node-id=104-35&t=68CvmXlAwhUrDkvy-1) in a new tab. Pass: `azlTesting321!`

2. Reopen the browser tab with the survey and complete question 2. [survey link](https://forms.office.com/r/4bBC2WZ5qG)

3. I'll tell you when to start [Task 3](task3.md)
