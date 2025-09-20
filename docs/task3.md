
# Task 3: Create a VM on your Azure Local cluster

## Context

- **Context:** You just deployed an Azure Local cluster, now you want to deploy a VM on the cluster.
- **Your goal:** Use the Azure portal to deploy a Windows Server 2025 VM on the cluster _azlcluster3_ in the resource group _azlrg3_.
- **Stop when:** VM deployment runs for ~30 seconds.

## Details

- **General:** You plan to use the VM for testing, not production. You want to manage the cluster’s operating system using Azure.
- **Resource group:** Create the VM in the same RG as the cluster.
- **VM size:** 2 CPUs and 4GBs of RAM.
- **OS:** Windows Server 2025. Use a Windows VHD file that is stored on the cluster at: `C:\ClusterStorage\UserStorage_2`. This image was previously downloaded from the Azure marketplace and stored on your cluster. The image is also already accessible in the Azure portal.
- **Storage:** Create a 100GB drive for application data.

### Network

1. Connect the VM to Azure using the public internet but don’t open any inbound ports.

2. Place the VM on the local network and in the same subnet as your cluster:
  - **Local network subnet**: 192.168.1.0 / 24
  - **RESERVED IPs in the subnet**:
    - All IPs used by AzLCluster3 
    - Local PC on the network: 192.168.1.20
    - All IPs between 192.168.200 - 192.168.255
  - **Default gateway**: 192.168.1.1
  - **No VLAN**


## End of task instructions

- **Stop when:** VM deployment runs for ~30 seconds.

## Next steps 
1. (Optional): Open the progress animation [prototype](https://www.figma.com/proto/iBO6B6vgjwlEzgv7p10qFi/AzL-Benchmark-Prototypes?node-id=57-1228&t=68CvmXlAwhUrDkvy-1) in a new tab. Pass: `azlTesting321!`

2. Reopen the browser tab with the survey and complete question 3. [survey link](https://forms.office.com/r/4bBC2WZ5qG)

3. I'll tell you when to start [Task 4](task4.md)
