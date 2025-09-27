# Task 1: Connect a server to Azure

## Task context 
**1. Read the slideshow images out loud:**
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

**2. Your goal:** Use the Configurator App to configure the server `AzLHOST1` and connect it to Azure.

## Detailed Instructions

### Remote Desktop

- **Log in to a remote desktop** that has the configurator app installed. Open the [remote desktop link](https://bst-a6e50e98-d3c2-4e4e-ab6f-6280cb4ea85b.bastion.azure.com/api/shareable-url/194ce359-20d0-44b1-ad02-ea7931a8ed4f) in a new tab. 
- **Username**: arcdemo
- **Pass**: azlTesting321!


### Once the desktop loads

1. Run the configurator app **as an administrator.**
2. Onboard the server `AzLHOST1` to Azure using the local admin account `administrator / azlTesting321!`


### Network

**1. Ensure `AzLHOST1`'s network adapters match this configuration.** (This is also the intended configuration for the 2-node cluster):

| Server name | Adapter Name | IP Address      | VLAN |
|-------------|--------------|-----------------|------|
| AzLHOST1    | FABRIC       | 192.168.1.11    | 0    |
| AzLHOST1    | StorageA     | Auto-assigned   | 711  |
| AzLHOST1    | StorageB     | Auto-assigned   | 712  |
| AzLHOST2    | FABRIC       | 192.168.1.12    | 0    |
| AzLHOST2    | StorageA     | Auto-assigned   | 711  |
| AzLHOST2    | StorageB     | Auto-assigned   | 712  |


**2. Join the server to the local network:**

- **Available IP addresses:** 192.168.1.11 – 192.168.1.199 (Except for 192.168.1.20, which is reserved.)
- **Subnet mask:** 255.255.255.0
- **Gateway:** 192.168.1.1
- **DNS:** 192.168.1.254
- **NTP:** Pacific



### Azure

- **Network:** Connect to the Azure public cloud using the public internet. Don’t use any additional proxies. Don’t open any inbound ports.
- **Tenant ID:** dcea112b-ec40-4856-b620-d8f34929a0e3
- **Subscription ID:** c45d4482-4bf4-4e6f-9fd1-aa3e8099e521
- **Resource group:** azlrg1
- **Region:** East US
- **Azure username:** azuser1@azlbenchmark.onmicrosoft.com
- **Pass:** _Temporary pass that was sent to you_

## End of task instructions

- **Stop when:** You verify the server onboarded to Azure. Let me know when you think you're done. 

## Next steps 

1. Open this [survey](https://forms.office.com/r/4bBC2WZ5qG) in a new tab and complete question 1. Leave the survey tab open then return back to the instructions. 
2. I'll tell you when to start [Task 2](task2.md)

