# Build you own Ansible VMware modules using powercli
### Why create your own module, and Why not from use the ansible provided VMware module?
Well, it is customizable and simple, and you can make your own module for anything you can do with powercli connecting to vcenter. The caevet is you would either need to make your ansible host run a powershell (there are docs to make it happen) or use the proxy powershell windows server (that can even be your vcenter server itself). In our case, we were already have Windows infrastructure connected to ansible host through WinRM. So we just spun off an intermediate Windows 2012 server that has powershell vmware powercli snap installed. Easy task for those who are using VMware powercli remotely, but beyond the scope of what is being disccussed here.
Here, I am just putting a sample of ansible powershell module that can connect to vcenter and get vmware details, and even more add to ansible facts with hiogh level of details about the VM.

## Uses:
Use the following task in your playbook to get VM details with few details - Name,powerstate,numcpu,memorygb,version
#### Module: get-vm
```- name: get vm details
    get_vm:
       VMname: "{{ ansible_host }}"
       VMuser: "vCenter_User"
       VMpass: "vCenter_Password"
       VCenter_Name: vCenter_Name
 ```
 Or, get even mode details - several properties, networking details, virtual details details, snapshot details and limitess other opprtunity if you add in more.
 #### Module: vmware_setup
```- name: get vm details
    vmware_setup:
       VMname: "{{ ansible_host }}"
       VMuser: "vCenter_User"
       VMpass: "vCenter_Password"
       VCenter_Name: vCenter_Name
 ```
 ## Explanation:
 While creating a module for powershell, you make sure you have these preliminary lines of codes as outlined in ansible module tutorial for powershell.
 > !powershell
 
 Also ansible has a built in functions to input and parse the parameters as json and output them as json.
 Example:
 ```
 $params = Parse-Args $args $true;
 ...
 $VMname = Get-Attr $params "VMname" -failifempty $TRUE
 ..
 Set-Attr $vm_property "numcpu" $VMobj.numcpu
 ...
 Exit-Json $result
 ```
You can see the rest of the codes are powershell with powercli call as usual.
