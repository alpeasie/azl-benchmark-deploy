# Task 1: Connect a server to Azure

## Overview

**Context:** You just purchased two servers from an OEM that you want to deploy as an Azure Local cluster. You racked the servers, cabled them, installed the OS. You also set up Azure tenant, subscription, and resource group. Now, you want to configure the servers and connect them to the cloud. To configure the servers, you will use an app called the Azure Local Configurator App. This app will be running on a laptop that has network connectivity to both servers.

**Your goal:** Use the Configurator App to configure the server `AzLHOST1` and connect it to Azure.

## Detailed Instructions

- Start the task via this url: **_enterurlhere_**. This will connect you to a desktop with the configurator app installed.
- Run the configurator app **as an administrator.**
- Onboard the server _AzLHOST1_ using the local admin account `administrator / azlTesting321!`

### Network

**1. Ensure the server's network adapters follow this configuration.** (This is also the intended configuration for the 2-node cluster):

| Server name | Adapter Name | IP Address      | VLAN |
|-------------|--------------|-----------------|------|
| AzLHOST1    | FABRIC       | 192.168.1.11    | 0    |
| AzLHOST1    | StorageA     | Auto-assigned   | 711  |
| AzLHOST1    | StorageB     | Auto-assigned   | 712  |
| AzLHOST2    | FABRIC       | 192.168.1.12    | 0    |
| AzLHOST2    | StorageA     | Auto-assigned   | 711  |
| AzLHOST2    | StorageB     | Auto-assigned   | 712  |


**2. Join the server to your local network:**

- **Available IP addresses:** 192.168.1.11 – 192.168.1.199 (Except for 192.168.1.20, which is reserved.)
- **Subnet mask:** 255.255.255.0
- **Gateway:** 192.168.1.1
- **DNS:** 192.168.1.254
- **NTP:** Pacific



### Azure

- **Network:** Connect to the Azure public cloud using the public internet. Don’t use any additional proxies. Don’t open any inbound ports.
- **Tenant ID:** dcea112b-ec40-4856-b620-d8f34929a0e3
- **Subscription ID:** 11bca099-3772-4ca6-9306-d0297f418192
- **Resource group:** azlrg1
- **Region:** East US
- **Username:** user1@azlbenchmark.onmicrosoft.com
- **Pass:** _Temporary pass that was sent to you_

## End of task instructions

- **Stop when:** You verify the server onboarded to Azure. Let me know when you think you're done. 

## Next steps 

- Open this [survey](https://forms.office.com/r/4bBC2WZ5qG) in a new tab and complete question 1. Leave the survey tab open. 
- Brief discussion.
- I'll tell you when to start [Task 2](task2.md)
