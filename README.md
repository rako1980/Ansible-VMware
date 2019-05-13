# Build you own Ansible VMware modules using powercli
### Why create your own module? Why not from VMware.
Well, it is customizable ans simple and can make your own module for anything you can do on vCenter. The caevet is you would either need to make your ansible host run a powershell (there are docs to make it happen) or use the proxy powershell windows server (that can even be your vcenter server). In our case, we were already have Windows infrastructure connected to ansible host through WinRM. So we just spun off an intermediate Windows 2012 server that has powershell vmware poercli snap installed. Easy task for those who are using VMware powershell, but beyond the scope of what is being disccussed here.
Here, I am just putting a sample of ansible powershell module that can connect to vcenter and get vmware details, and even more add to ansible facts with more details about the VM that would be {{ ansible_host }} you are interested on.

## Uses:
-- name: get vm details
   get_vm: 
