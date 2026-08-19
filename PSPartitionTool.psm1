function Test-DiskReady{
<#
.SYNOPSIS
Validates that the selected disk exists and is safe to modify.

.DESCRIPTION
Retrieves the specified disk and stops the workflow if the disk cannot be found or contains
the operating system.

.PARAMETER DiskNumber
Specifies the number of the disk to validate.

.PARAMETER Force
Allows validation to continue when the disk is marked as a system or boot disk.
Read-only and clustered disks remain blocked.

.NOTES
This function performs validation only; it does not modify the disk.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Switch]$Force
    )
    try{
        $DiskInfo = Get-Disk -Number $DiskNumber -ErrorAction Stop
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    if(-not $Force -and $DiskInfo.IsSystem){
        throw "The selected disk contains the operating system and cannot be modified."
    }
    if(-not $Force -and $DiskInfo.IsBoot){
        throw "The selected disk contains the boot partition and cannot be modified."
    }
    if($DiskInfo.IsReadOnly){
        throw "The selected disk is read-only and cannot be modified."
    }
    if($DiskInfo.IsClustered){
        throw "The selected disk belongs to a cluster and cannot be modified."
    }
    return $DiskInfo
}
function Initialize-ClearPartitions{
<#
.SYNOPSIS
Prepares the selected disk for a new partition layout.

.DESCRIPTION
Ensures that the specified disk is online and removes its existing data and OEM partitions.
Clear-Disk requests confirmation before performing the destructive operation.

.PARAMETER DiskNumber
Specifies the disk number to process.

.PARAMETER Force
Allows processing of a disk marked as a system or boot disk.
Read-only and clustered disks remain blocked.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Switch]$Force
    )
    try{
        $DiskInfo = Test-DiskReady -DiskNumber $DiskNumber -Force:$Force
        if($DiskInfo.IsOffline){
            Write-Verbose "Bringing disk $DiskNumber online..."
            $DiskInfo | Set-Disk -IsOffline $false -ErrorAction Stop | Out-Null
        }   else{
            Write-Verbose "Disk $DiskNumber is already online."
        }
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    try{
        Write-Verbose "Removing the partitions..."
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Initialize-StylePartition{
<#
.SYNOPSIS
Configures the selected disk to use the GPT partition style.

.DESCRIPTION
Checks the current partition style. RAW and Unknown disks are initialized as GPT, MBR disks
are converted to GPT, and disks already using GPT are left unchanged.

.PARAMETER DiskNumber
Specifies the disk number to process.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber
    )
    try{
        switch((Get-Disk -Number $DiskNumber -ErrorAction Stop).PartitionStyle){
            'RAW'{
                Write-Verbose "Initializing the disk using the GPT partition style."
                Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop | Out-Null
            }
            'Unknown'{
                Write-Verbose "Initializing the disk using the GPT partition style."
                Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop | Out-Null
            }
            'MBR'{
                Write-Verbose "Converting the partition style from MBR to GPT."
                Get-Disk -Number $DiskNumber | Set-Disk -PartitionStyle GPT -ErrorAction Stop | Out-Null
            }
            'GPT'{
                Write-Verbose "The disk already uses the GPT partition style."
            }
        }
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Initialize-NewPartitions{
<#
.SYNOPSIS
Creates and formats the requested number of partitions.

.DESCRIPTION
Creates one, two, or three partitions on the specified disk. For two partitions, the first
partition uses half of the disk and the second uses the remaining space. For three partitions,
the first two use one third each and the third uses the remaining space. Each partition is
formatted with the selected file system and assigned a drive letter.

.PARAMETER DiskNumber
Specifies the disk number to process.

.PARAMETER FileSystem
Specifies the file system used to format the new partitions.

.PARAMETER PartitionCount
Specifies the number of partitions to create.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Parameter(Mandatory = $true)]
        [ValidateSet('exFAT', 'NTFS')]
        [String]$FileSystem,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 3)]
        [Int32]$PartitionCount
    )
    $DiskSize = (Get-Disk -Number $DiskNumber -ErrorAction Stop).Size
    $HalfSize = [math]::Floor($DiskSize / 2)
    $ThirdSize = [math]::Floor($DiskSize / 3)
    try{
        switch($PartitionCount){
            1 {
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop | 
                    Format-Volume -FileSystem $FileSystem -ErrorAction Stop | Out-Null
                Write-Verbose "Partition created successfully."
            }
            2 {
                New-Partition -DiskNumber $DiskNumber -Size $HalfSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -ErrorAction Stop | Out-Null
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -ErrorAction Stop | Out-Null
                Write-Verbose "Both partitions were created successfully."
            }
            3 {
                New-Partition -DiskNumber $DiskNumber -Size $ThirdSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -ErrorAction Stop | Out-Null
                New-Partition -DiskNumber $DiskNumber -Size $ThirdSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -ErrorAction Stop | Out-Null
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop | 
                    Format-Volume -FileSystem $FileSystem -ErrorAction Stop | Out-Null
                Write-Verbose "All partitions were created successfully."
            }
        }
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Clear-Partition{
<#
.SYNOPSIS
Initializes the disk layout.

.DESCRIPTION
Clears the selected disk, configures the GPT partition style, creates the requested number of partitions, and formats each partition using the selected file system.

.PARAMETER DiskNumber
Specifies the disk number to process.

.PARAMETER FileSystem
Specifies the file system used to format the new partitions.

.PARAMETER PartitionCount
Specifies the number of partitions to create.

.PARAMETER Force
Allows processing of a disk marked as a system or boot disk.
Use this switch only when you have verified that the selected disk can be erased.
Read-only and clustered disks remain blocked.

.EXAMPLE
PS> Clear-Partition -DiskNumber 2 -FileSystem NTFS -PartitionCount 2

Clears disk 2, brings it online if necessary, configures GPT, creates two partitions, and formats
both partitions using NTFS.

.EXAMPLE
PS> Clear-Partition -DiskNumber 2 -FileSystem NTFS -PartitionCount 1 -Force

Erases and repartitions disk 2 even if Windows identifies it as a system or boot disk.
Use this only for a disk whose existing operating system and boot files should be removed.

.EXAMPLE
PS> Clear-Partition -DiskNumber 2 -FileSystem exFAT -PartitionCount 1 -WhatIf

Displays the operations that would be performed without modifying disk 2.

.NOTES
This is the main function of the script. It orchestrates validation, clearing, partition style
configuration, partition creation, and formatting.
The selected disk must not contain the operating system. Existing data on the selected disk is removed.
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Parameter(Mandatory = $true)]
        [ValidateSet('exFAT', 'NTFS')]
        [String]$FileSystem,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 3)]
        [Int32]$PartitionCount,

        [Switch]$Force
    )
    try{
        $DiskInfo = Test-DiskReady -DiskNumber $DiskNumber -Force:$Force
        $Target = "Disk $($DiskInfo.Number) - $($DiskInfo.FriendlyName) - $([math]::Round($DiskInfo.Size / 1GB, 2)) GB"
        if($PSCmdlet.ShouldProcess("$Target", "Clear, partition and format as $FileSystem")){
            Initialize-ClearPartitions `
                -DiskNumber $DiskNumber `
                -Force:$Force

            Initialize-StylePartition `
                -DiskNumber $DiskNumber

            Initialize-NewPartitions `
                -DiskNumber $DiskNumber `
                -FileSystem $FileSystem `
                -PartitionCount $PartitionCount
        }
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
Export-ModuleMember -Function Clear-Partition
