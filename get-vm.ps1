#!powershell
# <license>

# WANT_JSON
# POWERSHELL_COMMON


$params = Parse-Args $args $true;
$result = New-Object psobject @{
    ansible_facts = New-Object psobject
    changed = $false
}

#-- Required vCenter params
$VMname = Get-Attr $params "VMname" -failifempty $TRUE
$VCname = Get-Attr $params "VCname" -failifempty $TRUE
$VCuser = Get-Attr $params "VCuser" -failifempty $TRUE
$VCpass = Get-Attr $params "VCpass" -failifempty $TRUE

#-- Connect to vcenter
Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"

$VCConn = Connect-VIServer -Server $VCname -username $VCuser -password $VCpass -ea "Continue"
if (-Not $VCConn) { Fail-Json $result "vCenter Connection failed: $error" }

## Get VM details
$VMobj = Get-VM $VMname | Select Name,powerstate,numcpu,memorygb,version -ea "Continue"
if (-not $VMobj) { Fail-Json $result "Could not retrieve VM ($VMname) detail: $error" }

$result = $VMobj
Exit-Json $result
