
# Task 2: Deploy a 2-node Azure Local cluster
## Overview 

**Context:** You connected two server nodes to the Azure cloud. Now, you want to deploy a 2-node Azure Local cluster.

**Your goal:** Use the Azure portal to deploy an Azure Local cluster using the servers `AzLHOST1` and `AzLHOST2` in the resource group `azlrg2`.

**Stop when:** Azure Local cluster deployment starts.

**Prerequisite step:** Sign into Azure portal. 

1. Open a new incognito browser window for the [azure portal](https://portal.azure.com/)
2. Sign in with the Azure creds provided in Teams. 


## Cluster details 

Use the following details to help you create the cluster. If the instructions do not specify a configuration (like what to name the cluster), choose a name based on your professional opinion and the context provided in the task.

### Azure configuration

- **Resource group:** Create the cluster in the same RG of the servers, `azlrg2`
- **Subscription:** Azl S3
- **Region:** East US

### Physical cluster network details 

Each server has 3 network adapters: 

- 1 adapter for workloads and management. These are cabled to a network switch. 
- 2 adapters for storage, which are directly connected. 
The diagram below shows how these servers are cabled. 

![Cluster network diagram](images/servercable.png)


### Local network details (LAN)
Deploy the cluster on the following local network. Ensure the cluster and cluster workloads will be accessible. 

- **Subnet:** 192.168.1.0 / 24
- **Default gateway:** 192.168.1.1
- **DNS server:** 192.168.1.254
- **Available IP addresses:** 192.168.1.11 – 192.168.1.200 (except for 192.168.1.20, which is the IP of the machine you’re currently using on the network).

### Network design instructions  
1. Keep storage traffic isolated from workloads & server/ cluster management. Create two subnets for storage traffic on different VLANs. 
2. Ensure the cluster and its workloads are accessible on the local (LAN) network. Assign the smallest number of IP addresses required for the cluster on the local network. 
3. Maximize the MTU on storage links, use the default for workloads & management. 


### Intended network adapter configuraiton
Use the following table to help configure the cluster network and it's adapters. 

| Server name | Adapter Name | IP Address      | VLAN | MTU     |
|-------------|--------------|-----------------|------|---------|
| AzLHOST1    | FABRIC       | 192.168.1.11    | 0    | Default |
| AzLHOST1    | StorageA     | Auto-assigned   | 711  | Max     |
| AzLHOST1    | StorageB     | Auto-assigned   | 712  | Max     |
| AzLHOST2    | FABRIC       | 192.168.1.12    | 0    | Default |
| AzLHOST2    | StorageA     | Auto-assigned   | 711  | Max     |
| AzLHOST2    | StorageB     | Auto-assigned   | 712  | Max     |





## Active Directory & credentials

- Join the cluster to the domain: `jumpstart.local`
- OU formatting: `OU=hcioudocs,DC=jumpstart,DC=local`
- Domain creds: `localboxdeployuser/azlTesting321!`
- Local admin creds: `administrator/azlTesting321!`

## Cluster features

- Ensure the cluster follows security best practices for a test cluster but disable bitlocker
- Create multiple cluster shared volumes for workloads


## End of task instructions

**Stop when:** Azure Local cluster deployment starts. Let me know when you think you're done. 

## Next steps 

1. Open this link in a new tab: [prototype](https://www.figma.com/proto/iBO6B6vgjwlEzgv7p10qFi/AzL-Benchmark-Prototypes?node-id=104-35&t=68CvmXlAwhUrDkvy-1) in a new tab. Pass: `azlTesting321!`

2. Reopen the browser tab with the survey and complete question 2: [survey](https://forms.office.com/r/4bBC2WZ5qG)

3. I'll tell you when to start [Task 3](task3.md)
