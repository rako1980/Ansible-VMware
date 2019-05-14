#!powershell
# <license>

# WANT_JSON
# POWERSHELL_COMMON


$params = Parse-Args $args $true;
$result = New-Object psobject @{
    ansible_facts = New-Object psobject
    changed = $false
}

## Connect to vCenter
$VMname = Get-Attr $params "VMname" -failifempty $FALSE
$VCname = Get-Attr $params "VCname" -failifempty $FALSE
$VCuser = Get-Attr $params "VCuser" -failifempty $FALSE
$VCpass = Get-Attr $params "VCpass" -failifempty $FALSE

# vcenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
$VCConn = Connect-VIServer -Server $VCname -username $VCuser -password $VCpass -ea "Continue"
if (-Not $VCConn) { Fail-Json $result "vCenter Connection failed: $error" }

## Get VM details
#$VMobj = Get-VM $VMname | Select id,name,powerstate,numcpu,memorygb,version,persistentID,Folder -ea "Continue"
$VMobj = Get-VM $VMname
if (-not $VMobj) { Fail-Json $result "Could not retrieve VM ($VMname) detail: $error" }

## Also get all View info for later use
$VM_view_obj = Get-VM $VMname | Get-View -ea "Continue"
$vmDatacenterView = Get-VM -Name $vmName | Get-Datacenter | Get-View
$virtualDiskManager = Get-View -Id VirtualDiskManager-virtualDiskManager

## Extended VM details
$VM_Ext_obj = Get-VM $VMname | Get-View | Select-Object @{Name="VmwareToolsStatus";E={$_.Guest.ToolsStatus}} -ea "Continue"
if (-not $VM_Ext_obj) { Fail-Json $result "Could not retrieve VM ($VMname) Views: $error" }

## Hosts Cluster Name
$VMHostClusterObj = Get-VM $VMname | Select-Object -Property Name,@{Name=’Cluster’;Expression={$_.VMHost.Parent}}

$HWversion = [int]($VMobj.Version) + 5
$vmfolder = [string]$VMobj.Folder
$vmhost = [string]$VMobj.VMHost
$vmcluster = [string]$VMHostClusterObj.Cluster

$vm_property = New-Object psobject
Set-Attr $vm_property "vmid" $VMobj.id
Set-Attr $vm_property "numcpu" $VMobj.numcpu
Set-Attr $vm_property "powerstate" $VMobj.powerstate
Set-Attr $vm_property "memorygb" $VMobj.memorygb
Set-Attr $vm_property "hwversion" $HWversion
Set-Attr $vm_property "PersistentID" $VMobj.PersistentID
Set-Attr $vm_property "name" $VMobj.name
Set-Attr $vm_property "vmhost" $vmhost
Set-Attr $vm_property "vmhostcluster" $vmcluster
Set-Attr $vm_property "folder" $vmfolder
Set-Attr $vm_property "vcenter" $VCname
Set-Attr $vm_property "VmwareToolsStatus" $VM_Ext_obj.VmwareToolsStatus
Set-Attr $vm_property "nsx_manager" $nsxConn.Server
Set-Attr $vm_property "nsx_security_tag" $nsxTags.Name
Set-Attr $result.ansible_facts "vmware" $vm_property



## Get VM networking details
$VM_Net_obj = Get-NetworkAdapter -VM $VMname | Select Name,Type,NetworkName
$network_properties = New-Object psobject
Set-Attr $result.ansible_facts.vmware "networks" $network_properties
ForEach ($obj in $VM_Net_Obj) {
        $network_interface = New-Object psobject
        Set-Attr $network_interface "Name" $obj.Name
        Set-Attr $network_interface "Type" $obj.Type
        Set-Attr $network_interface "Network_Name" $obj.NetworkName
        Set-Attr $result.ansible_facts.vmware.networks $network_interface.Name $network_interface
}

## Get disks details
$VM_disks_obj = Get-Harddisk -VM $VMname | Select Name,Filename,CapacityGB,DiskType,StorageFormat
#$view = Get-VM $VMname
$disk_properties = New-Object psobject
Set-Attr $result.ansible_facts.vmware "disks" $disk_properties
ForEach ($obj in $VM_disks_obj) {
        # Get scsi info for this disk
        $scsi_obj = $VM_view_obj.Config.Hardware.Device | where {$_.GetType().Name -eq "VirtualDisk"} | where {$_.DeviceInfo.Label -eq $obj.Name}

        $disk_obj = New-Object psobject
        Set-Attr $disk_obj "Name" $obj.Name
        Set-Attr $disk_obj "Filename" $obj.Filename
        Set-Attr $disk_obj "CapacityGB" $obj.CapacityGB
        Set-Attr $disk_obj "DiskType" $obj.DiskType
        Set-Attr $disk_obj "StorageFormat" $obj.StorageFormat

        Set-Attr $disk_obj "scsi_controller_key" $scsi_obj.ControllerKey
        Set-Attr $disk_obj "scsi_unit_number" $scsi_obj.UnitNumber
        $scsi_disk = [string]([int]$scsi_obj.ControllerKey - 1000) + ":" + $scsi_obj.UnitNumber
        Set-Attr $disk_obj "scsi_disk" $scsi_disk

        $vmHardDiskUuid = $virtualDiskManager.queryvirtualdiskuuid($obj.Filename, $vmDatacenterView.MoRef) |  foreach {$_.replace(' ','').replace('-','')}

        $vmHardDiskUuid = $vmHardDiskUuid.ToLower()
        Set-Attr $disk_obj "vmdisk_uuid" $vmHardDiskUuid

        Set-Attr $result.ansible_facts.vmware.disks $vmHardDiskUuid $disk_obj
        Set-Attr $result.ansible_facts.vmware.disks $obj.Name $disk_obj
}

#Set-Attr $result.ansible_facts.vmware.disks "6000c29a02fc5c60a76bb7bcd711dfab" "testing1"
#Set-Attr $result.ansible_facts.vmware.disks "6000c29a02fc5c60a76bb7bcd711dfac" "testing2"

## Snapshot Details
$VM_Snp_obj = Get-VM $VMname | Get-Snapshot -ea "Continue"
If (-not $VM_Snp_obj) {
        Set-Attr $result.ansible_facts.vmware "snapshot_present" $false
} Else {
        Set-Attr $result.ansible_facts.vmware "snapshot_present" $true
        $snap_properties = New-Object psobject
        Set-Attr $result.ansible_facts.vmware "snapshots" $snap_properties
        ForEach ($obj in $VM_Snp_obj) {
                $snap_obj = New-Object psobject
                Set-Attr $snap_obj "Name" $obj.Name
                Set-Attr $snap_obj "Description" $obj.Description
                Set-Attr $snap_obj "Date" $obj.Created
                Set-Attr $snap_obj "SizeGB" $obj.SizeGB
                Set-Attr $result.ansible_facts.vmware.snapshots $snap_obj.Name $snap_obj
        }
}

## Check vSphere Replication
$VM_Rep_obj = Get-VM $VMname | Get-VIEvent | Where { $_.EventTypeId -match "hbr|rpo" } -ea "Continue"
If (-not $VM_Rep_obj) {
        Set-Attr $result.ansible_facts.vmware "replication_present" $false
} Else {
        Set-Attr $result.ansible_facts.vmware "replication_present" $true
}

Exit-Json $result
