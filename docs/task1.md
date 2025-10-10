# Task 1: Connect a server to Azure

## Overview
You just purchased a new 2-node Azure Local cluster. You want to configure the servers and connect them to Azure. 

For more context, read the slideshow below:
<div class="carousel">
  <input type="radio" name="slides" id="slide1" checked>
  <input type="radio" name="slides" id="slide2">
  <input type="radio" name="slides" id="slide3">
  <input type="radio" name="slides" id="slide4">
  
<div class="carousel-slides">
  <img src="../images/oobe0.png" alt="1: Purchase servers">
  <img src="../images/oobe1.png" alt="2: Set up Azure">
  <img src="../images/oobe2.png" alt="3: OEM ships">
  <img src="../images/oobe3.png" alt="4: Open config app">
</div>
  <div class="carousel-nav">
    <label for="slide1"></label>
    <label for="slide2"></label>
    <label for="slide3"></label>
    <label for="slide4"></label>
  </div>
</div>


### Your goal  
Use the Configurator App to configure one of your servers and connect it to Azure. **Server name:** AzLHOST1 


## Detailed Instructions

### Remote Desktop

- **Log in to a remote desktop** that has the configurator app installed. In a new tab, open the [remote desktop link](https://bst-a6e50e98-d3c2-4e4e-ab6f-6280cb4ea85b.bastion.azure.com/api/shareable-url/f4dd6cc2-c8c2-4f85-8c49-dcbc155981b6).

- **Username**: arcdemo
- **Pass**: azlTesting321!


### After the remote desktop loads

1. Run the configurator app **as an administrator.**
2. Connect to the server **AzLHOST1** using the local admin credentials:

- **Usernme**:  administrator
- **Password**: azlTesting321!


### Network details

**1. The server's network adapters should use the following configuration.**

**Note: Only the FABRIC adapter** has connectivity to the internet. This is also the configuration that you'll use for creating the 2-node cluster later on. 

| Server name | Adapter Name | IP Address      | VLAN |
|-------------|--------------|-----------------|------|
| AzLHOST1    | FABRIC       | 192.168.1.11    | 0    |
| AzLHOST1    | StorageA     | Auto-assigned   | 711  |
| AzLHOST1    | StorageB     | Auto-assigned   | 712  |


**2. Ensure the server will be accessible on the local network :**

- **Available IP addresses:** 192.168.1.11 – 192.168.1.199 (Except for 192.168.1.20, which is reserved.)
- **Subnet mask:** 255.255.255.0
- **Gateway:** 192.168.1.1
- **DNS:** 192.168.1.254
- **NTP:** Pacific



### Azure details

- **Network:** Connect to the Azure public cloud using the public internet. Don’t use any additional proxies. Don’t open any inbound ports.
- **Tenant ID:** `dcea112b-ec40-4856-b620-d8f34929a0e3`
- **Subscription ID:** `c45d4482-4bf4-4e6f-9fd1-aa3e8099e521`
- **Resource group:** azlrg1
- **Region:** East US
- **Azure creds:** _Temporary username & pass that was sent to you via Teams_

### Stop when

You verify the server onboarded to Azure. Let me know when you think you're done. 


## After task 1 is complete 

1. In a new tab, open this [survey](https://forms.office.com/r/4bBC2WZ5qG) and complete question 1. Leave the survey tab open then return back to the instructions. 
2. I'll tell you when to start [Task 2](task2.md)

