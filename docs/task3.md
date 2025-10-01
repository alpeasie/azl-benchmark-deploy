
# Task 3: Create a VM on your Azure Local cluster

- **Context:** You just deployed an Azure Local cluster. Now, you want to create a VM on the cluster for testing purposes. 
- **Your goal:** Use the Azure portal to deploy a Windows Server 2025 VM on the cluster `azlcluster3` in the resource group `azlrg3`.
- **Stop when:** The VM resource is created.

## Details

- **Resource group:** Create the VM in the same RG as the cluster.
- **General:** You want to manage the cluster’s operating system using Azure.
- **VM size:** 2 CPUs and 4GBs of RAM.
- **OS:** Windows Server 2025. Use a .vhdx file that is stored on the cluster at: `C:\ClusterStorage\UserStorage_2`. This image was previously downloaded from the Azure marketplace to your cluster, and it is accessible via the Azure portal. 
- **VM path:** Save the VM in this same cluster-shared volume as the OS .vhdx file. 
- **Access control:** Do not join the VM to a domain.
- **Storage:** Create a 100GB drive for application data.

### Network

1. Connect the VM to Azure using the public internet and no proxies. Don't modify the port configurations. 

2. Place the VM on your local network (LAN) and in the same subnet as your cluster.

**Local network details:**

  - **Local network subnet**: 192.168.1.0 / 24
  - **Default gateway**: 192.168.1.1
  - **VLAN**: 0
  - **DNS server**: 192.168.1.254
  - **IPs currently in use on the subnet**:
    - All IP addresses used by azlcluster3 (which are the same IPs you defined in Task 2).
    - All IPs between: 192.168.200 - 192.168.255. 
    - 192.168.1.20



## End of task instructions

**Stop when:** The VM resource is created.

## After task 3

1. (Optional) I'll tell you whether to open this link in a new tab: [prototype](https://www.figma.com/proto/iBO6B6vgjwlEzgv7p10qFi/AzL-Benchmark-Prototypes?node-id=57-1228&p=f&viewport=1477%2C713%2C0.1&t=nc4yBratS5PjalR7-0&scaling=min-zoom&content-scaling=fixed&starting-point-node-id=104%3A45&show-proto-sidebar=1). Pass: `azlTesting321!`

2. Reopen the browser tab with the survey and complete question 3. [survey link](https://forms.office.com/r/4bBC2WZ5qG)

3. I'll tell you when to start [Task 4](task4.md)
