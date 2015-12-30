<#  
 .SYNOPSIS  
  Gets the complete virtual portgroup information  
 .DESCRIPTION  
  This script creates a report of complete virtual portGroup information  
  of the vm’s guest OS  
 .NOTES  
  Find more information on http://kunaludapi.blogspot.com  
  Make sure you have installed Powercli and can connect to vcenter.  
 .EXAMPLE  
  PS C:\Temp> .\Get-VirtualPortGroupInfo.ps1  
 .EXAMPLE  
  PS C:\Temp> .\Get-VirtualPortGroupInfo.ps1 | Export-Csv -NoTypeInformation -Path C:\Temp\NetworkInformation.csv  
 #>  
   
  #####################################    
  ## http://kunaludapi.blogspot.com    
  ## Version: 1    
  ##    
  ## Tested this script on    
  ## 1) Powershell v4    
  ## 2) VMware vSphere PowerCLI 6.0 Release 1 build 2548067   
  ## 3) Vsphere 5.5    
  #####################################    
 Begin {  
 if (-not(Get-PSSnapin vmware.vimautomation.core -ErrorAction SilentlyContinue)) {  
   Add-PSSnapin vmware.vimautomation.core -ErrorAction SilentlyContinue  
 }  
 $report = @()  
 $IPregex=‘(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))’  
 $VMHosts = Get-VMHost  
 } #begin  
 Process {  
   foreach ($esxi in $VMHosts) {  
   Write-Host "Collecting PortGroups from Esxi Server `"$($esxi.Name)`"" -BackgroundColor DarkGreen  
   
   #All PortGroups in esxi server  
   $PortGroup = $esxi | Get-VirtualPortGroup  
     
   #iSCSI software adapter on esxi  
   $iSCSIHBA = $esxi | Get-VMHostHba -Device $HBA -Type iSCSI | Where-Object {$_.Model -eq "iSCSI Software Adapter"}  
   
   #All VMKernel Ports on esxi Server  
   $VMkernelPorts = $esxi | Get-VMHostNetworkAdapter -Name vmk*  
   
   #Esxicli information of esxi server  
   $esxcli = $esxi | Get-EsxCli  
   
     foreach ($Group in $PortGroup) {  
       Write-Host "`tFetching Info from Portgroup `"$($Group.Name)`"" -ForegroundColor Yellow  
         
       $Obj = New-Object psobject  
       $Obj | Add-Member -Name EsxiName -MemberType NoteProperty -Value $esxi.Name  
       $Obj | Add-Member -Name PortGroup -MemberType NoteProperty -Value $Group.Name  
       $Obj | Add-Member -Name VLanId -MemberType NoteProperty -Value $Group.VLanId  
       $Obj | Add-Member -Name vSwitch -MemberType NoteProperty -Value $Group.VirtualSwitchName  
         
       #Find whether PortGroup is VMKernel or VirtualMachine  
       if ($VMkernelPorts.PortGroupName -contains $group.Name) {  
         $Portgrouptype = "VMKernel"  
       } #if ($VMkernelPorts.PortGroupName -contains $group.Name)  
       else {  
         $Portgrouptype = "VirtualMachine"  
       } #else #if ($VMkernelPorts.PortGroupName -contains $group.Name)  
         $Obj | Add-Member -Name PortGroupType -MemberType NoteProperty -Value $Portgrouptype  
       
       $Macs = $Group.ExtensionData.port.mac -join ", "  
         $Obj | Add-Member -Name Mac -MemberType NoteProperty -Value $Macs  
       
       $Obj | Add-Member -Name AllowPromiscuous -MemberType NoteProperty -Value $Group.ExtensionData.ComputedPolicy.security.AllowPromiscuous  
       $Obj | Add-Member -Name MacChanges -MemberType NoteProperty -Value $Group.ExtensionData.ComputedPolicy.security.MacChanges  
       $Obj | Add-Member -Name ForgedTransmits -MemberType NoteProperty -Value $Group.ExtensionData.ComputedPolicy.security.ForgedTransmits  
   
       #Teaming Policy  
       $NicTeamingPolicy = Get-NicTeamingPolicy -VirtualPortGroup $Group  
         $Obj | Add-Member -Name IsLoadBalancingInherited -MemberType NoteProperty -Value $NicTeamingPolicy.IsLoadBalancingInherited  
       
       $LoadBalancing = $Group.ExtensionData.ComputedPolicy.NicTeaming.Policy  
         switch ($LoadBalancing)   
           {   
             loadbalance_ip {$LoadBalancingPolicy = "Route based on IP hash"}   
             loadbalance_srcmac {$LoadBalancingPolicy = "Route based on source MAC hash"}   
             loadbalance_srcid {$LoadBalancingPolicy = "Route based on the source of the port ID"}   
             failover_explicit {$LoadBalancingPolicy = "use explicity failover order"}   
             default {$LoadBalancingPolicy = "Can't Determine"}  
           } #switch ($LoadBalancing)  
         $Obj | Add-Member -Name LoadBalancing -MemberType NoteProperty -Value $LoadBalancingPolicy  
       
       $Obj | Add-Member -Name IsNetworkFailoverDetectionInherited -MemberType NoteProperty -Value $NicTeamingPolicy.IsNetworkFailoverDetectionInherited  
       $Obj | Add-Member -Name NetworkFailoverDetection -MemberType NoteProperty -Value $NicTeamingPolicy.NetworkFailoverDetectionPolicy  
       $Obj | Add-Member -Name IsNotifySwitchesInherited -MemberType NoteProperty -Value $NicTeamingPolicy.IsNotifySwitchesInherited  
       $Obj | Add-Member -Name NotifySwitches -MemberType NoteProperty -Value $Group.ExtensionData.ComputedPolicy.NicTeaming.NotifySwitches  
       $Obj | Add-Member -Name IsFailbackInherited -MemberType NoteProperty -Value $NicTeamingPolicy.IsFailbackInherited  
       $Obj | Add-Member -Name Failback -MemberType NoteProperty -Value $Group.ExtensionData.ComputedPolicy.NicTeaming.RollingOrder  
       $Obj | Add-Member -Name IsFailoverOrderInherited -MemberType NoteProperty -Value $NicTeamingPolicy.IsFailoverOrderInherited  
   
       $ActiveNics = $Group.ExtensionData.ComputedPolicy.NicTeaming.NicOrder.ActiveNic -join ", "  
         $Obj | Add-Member -Name ActiveNics -MemberType NoteProperty -Value $ActiveNics  
       $StandbyNics = $Group.ExtensionData.ComputedPolicy.NicTeaming.NicOrder.StandbyNics -join ", "  
         $Obj | Add-Member -Name StandbyNics -MemberType NoteProperty -Value $StandbyNics  
       $UnusedNics = $NicTeamingPolicy.UnusedNic -join ", "  
         $Obj | Add-Member -Name UnusedNics -MemberType NoteProperty -Value $UnusedNics  
       
       #All VMs having assigned PortGroup  
       $IPv4Address = $null  
       if ($Portgrouptype -eq "VirtualMachine") {  
         $VMList = $null  
         $VMList = $Group | Get-VM  
         $VMs = $null  
         $VMs = $($VMList | Select-Object -ExpandProperty Name) -join ", "  
         $IPlist = $VMList.guest.Nics | Where-Object {$_.NetworkName -eq $Group.Name}  
         $IPv4List = $IPlist.IpAddress | Where-Object {$_ -match $IPregex}  
         $IPv4Address = $IPv4List -Join ", "  
         $IPv4SubnetMask = $null  
         $PortBindingCompliance = $null  
         $MTU = $null  
         $VmkernelNic = $null  
         $PathStatus = $null  
         $MGMT = $null  
         $vMotion = $null  
         $FT = $null  
         $vSAN = $null  
           
       } #if ($Portgrouptype -eq "VirtualMachine")  
       else {  
         $iSCSIPortGroup = $esxcli.iscsi.networkportal.list($iSCSIHBA.Name).PortGroup | Where-Object {$_ -eq $Group.Name}  
         $VmkernelNicinfo = $VMkernelPorts | Where-Object {$_.PortGroupName -eq $Group.Name}  
         if ($iSCSIPortGroup -ne $null) {  
           $VMList = $null  
           $VMs = $null  
           $PortBinding = "Configured"  
           $IPv4Address = $esxcli.iscsi.networkportal.list($iSCSIHBA.Name) | Where-Object {$_.PortGroup -eq $iSCSIPortGroup} | Select-Object -ExpandProperty IPv4  
           $IPv4SubnetMask = $esxcli.iscsi.networkportal.list($iSCSIHBA.Name) | Where-Object {$_.PortGroup -eq $iSCSIPortGroup} | Select-Object -ExpandProperty IPv4SubnetMask  
           $PortBindingCompliance = $esxcli.iscsi.networkportal.list($iSCSIHBA.Name) | Where-Object {$_.PortGroup -eq $iSCSIPortGroup} | Select-Object -ExpandProperty CompliantStatus  
           $MTU = $esxcli.iscsi.networkportal.list($iSCSIHBA.Name) | Where-Object {$_.PortGroup -eq $iSCSIPortGroup} | Select-Object -ExpandProperty MTU  
           $VmkernelNic = $esxcli.iscsi.networkportal.list($iSCSIHBA.Name) | Where-Object {$_.PortGroup -eq $iSCSIPortGroup} | Select-Object -ExpandProperty Vmknic  
           $PathStatus = $esxcli.iscsi.networkportal.list($iSCSIHBA.Name) | Where-Object {$_.PortGroup -eq $iSCSIPortGroup} | Select-Object -ExpandProperty PathStatus  
           $MGMT = $VmkernelNicinfo.ManagementTrafficEnabled  
           $vMotion = $VmkernelNicinfo.vMotionEnabled  
           $FT = $VmkernelNicinfo.FaultToleranceLoggingEnabled  
           $vSAN = $VmkernelNicinfo.VsanTrafficEnabled  
         } #if ($iSCSIPortGroup -ne $null)  
         else {  
           $VMList = $null  
           $VMs = $null  
           $IPv4Address = $VmkernelNicinfo.IP  
           $IPv4SubnetMask = $VmkernelNicinfo.SubnetMask  
           $PortBindingCompliance = "Not Configured"  
           $MTU = $VmkernelNicinfo.Mtu  
           $VmkernelNic = $VmkernelNicinfo.Name  
           $PathStatus = $null  
           $MGMT = $VmkernelNicinfo.ManagementTrafficEnabled  
           $vMotion = $VmkernelNicinfo.vMotionEnabled  
           $FT = $VmkernelNicinfo.FaultToleranceLoggingEnabled  
           $vSAN = $VmkernelNicinfo.VsanTrafficEnabled  
         } #else #if ($iSCSIPortGroup -ne $null)  
       } #if ($Portgrouptype -eq "VirtualMachine")  
       $Obj | Add-Member -Name VMCount -MemberType NoteProperty -Value $VMList.count  
       $Obj | Add-Member -Name VMs -MemberType NoteProperty -Value $VMs  
       $Obj | Add-Member -Name IPv4Address -MemberType NoteProperty -Value $IPv4Address  
       $Obj | Add-Member -Name IPv4SubnetMask -MemberType NoteProperty -Value $IPv4SubnetMask  
       $Obj | Add-Member -Name PortBindingCompliance -MemberType NoteProperty -Value $PortBindingCompliance  
       $Obj | Add-Member -Name MTU -MemberType NoteProperty -Value $MTU  
       $Obj | Add-Member -Name VmkernelNic -MemberType NoteProperty -Value $VmkernelNic  
       $Obj | Add-Member -Name PathStatus -MemberType NoteProperty $PathStatus  
       $Obj | Add-Member -Name MGMT-Enabled -MemberType NoteProperty $MGMT  
       $Obj | Add-Member -Name vMotion-Enabled -MemberType NoteProperty $vMotion  
       $Obj | Add-Member -Name FT-Enabled -MemberType NoteProperty $vMotion  
       $Obj | Add-Member -Name vSAN-Enabled -MemberType NoteProperty $vSan  
       $report += $obj  
       #check under $NicTeamingPolicy more settings   
     } #foreach ($Group in $PortGroup)  
   } #foreach ($esxi in $VMHosts)  
 } #Process  
 End {  
   $report #| Export-Csv C:\Temp\NetworkInfo.csv -NoTypeInformation  
 } #End  