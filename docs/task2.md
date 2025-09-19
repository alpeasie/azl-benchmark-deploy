
# Task 2: Deploy a 2-node Azure Local cluster

## Overview

**Context:** You connected two server nodes to the Azure cloud. Now, you want to deploy a 2-node Azure Local cluster.

**Your goal:** Use the Azure portal to deploy an Azure Local cluster with the servers _azlnode1_ and _azlnode2_ in the resource group _azlrg2_.

**Stop when:** Azure Local cluster deployment starts.

## Detailed instructions

Use the following details to help you create the cluster. If the task does not explicitly state what to type or select in an input field, use your best judgement to determine how to proceed.

### Azure configuration

- **Resource group:** Create the cluster in the same RG of the servers, _azlrg2_
- **Region:** East US

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
- Domain username: `localboxdeployuser`
- Pass: `azlTesting321!`
- Local username: `administrator`
- Pass: `azlTesting321!`

### Cluster features

- Ensure the cluster follows security best practices for a test cluster but disable bitlocker
- Create multiple cluster shared volumes for workloads


## End of task instructions

- **Stop when:** Azure Local cluster deployment starts. Let me know when you think you're done. 

## Next steps 

- Reopen the browser tab with the survey and complete question 2. [survey link](https://forms.office.com/r/4bBC2WZ5qG)
- Brief discussion.
- I'll tell you when to start [Task 3](task3.md)
