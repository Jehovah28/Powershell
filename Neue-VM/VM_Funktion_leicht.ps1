function Neue-VM {
[cmdletbinding()] 

param (

[parameter(Mandatory,HelpMessage='Bitte den VM-Namen angeben')]
[string]$VMName,

[ValidateSet(1,2)]
$VMGeneration= 2,

[parameter(Mandatory)]
# uint ist für eine Gen 2 VM erforderlich
# für die Verwendung als Parameter ist die Angabe optional
[uint64]$VMMemory=1GB
)

$VMLocation = 'D:\VMs'
$VMNetwork = 'Lab'

# VM erstellen
$VMDiskSize = 300GB
if ($VMMemory -ne $null)
    {
    New-VM -Name $VMName -Generation $VMGeneration -MemoryStartupBytes $VMMemory -SwitchName $VMNetwork -Path $VMLocation -NoVHD -Verbose
    New-VHD -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" -SizeBytes $VMDiskSize -Verbose
    Add-VMHardDiskDrive -VMName $VMName -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" -Verbose
    }
else 
    {
    # mit Default Arbeitsspeicher
    New-VM -Name $VMName -Generation $VMGeneration -SwitchName $VMNetwork -Path $VMLocation -NoVHD -Verbose
    New-VHD -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" -SizeBytes $VMDiskSize -Verbose
    Add-VMHardDiskDrive -VMName $VMName -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" -Verbose
    }
}