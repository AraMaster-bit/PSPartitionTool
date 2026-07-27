<#
.SYNOPSIS
Removes all partitions from the specified disk.

.DESCRIPTION
Clears all partitions from the specified disk and ensures that the disk is online before continuing.

.PARAMETER DiskNumber
Specifies the disk number to process.

.EXAMPLE
PS> Clear-DiskPartitions -DiskNumber 2

Removes all partitions from disk 2 and brings the disk online if necessary.

.NOTES
This function is executed as the second step of the disk initialization workflow. It removes all existing partitions 
from the selected disk and verifies that the disk is online before continuing.
#>
function Clear-DiskPartitions{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber
    )
    try{
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -confirm:$false -ErrorAction Stop
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    try{
        if((Get-Disk -Number $DiskNumber).IsOffline){
            Write-Verbose "Bringing the disk online..."
            Get-Disk -Number $DiskNumber | Set-Disk -IsOffline $false -ErrorAction Stop
        }   else{
                Write-Verbose "The disk is already online."
            }
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
<#
.SYNOPSIS
Initializes the partition style of the specified disk.

.DESCRIPTION
Checks the current partition style of the specified disk. If the disk uses the RAW, Unknown, or MBR partition style, 
it is converted to GPT. If the disk already uses GPT, no changes are made.

.PARAMETER DiskNumber
Specifies the disk number to process.

.EXAMPLE
PS> Initialize-DiskPartitionStyle -DiskNumber 2

Checks the partition style of disk 2 and converts it to GPT if required.

.NOTES
This function is executed after the disk has been cleared. It ensures that the disk uses the GPT partition style before new partitions are created.
#>
function Initialize-DiskPartitionStyle{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber
    )
    try{
        switch((Get-Disk -Number $DiskNumber).PartitionStyle){
            'RAW'{
                Write-Verbose "Initializing the disk using the GPT partition style."
                Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop
            }
            'Unknown'{
                Write-Verbose "Initializing the disk using the GPT partition style."
                Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop
            }
            'MBR'{
                Write-Verbose "Converting the partition style from MBR to GPT."
                Get-Disk -Number $DiskNumber | Set-Disk -PartitionStyle GPT -ErrorAction Stop
            }
            'GPT'{
                Write-Verbose "The disk already uses the GPT partition style."
            }
        }
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
<#
.SYNOPSIS
Creates and formats new disk partitions.

.DESCRIPTION
Creates one to three partitions on the specified disk and formats each partition using the selected file system.

.PARAMETER DiskNumber
Specifies the disk number to process.

.PARAMETER FileSystem
Specifies the file system used to format the new partitions.

.PARAMETER PartitionCount
Specifies the number of partitions to create.

.EXAMPLE
PS> New-DiskPartitions -DiskNumber 2 -FileSystem NTFS -PartitionCount 2

Creates two partitions on disk 2 and formats both partitions using NTFS.

.NOTES
This function is executed after the disk has been initialized with the GPT partition style. It creates the requested 
number of partitions and formats each one using the selected file system.
#>
function New-DiskPartitions{
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
    $DiskSize = (Get-Disk -Number $DiskNumber).Size
    $HalfSize = [math]::Floor($DiskSize / 2)
    $ThirdSize = [math]::Floor($DiskSize / 3)
    try{
        switch($PartitionCount){
            '1'{
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop | 
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel "Vol A" -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Verbose "Partition created successfully."
            }
            '2'{
                New-Partition -DiskNumber $DiskNumber -Size $HalfSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel "Vol A" -Confirm:$false -ErrorAction Stop | Out-Null
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel "Vol B" -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Verbose "Both partitions were created successfully."
            }
            '3'{
                New-Partition -DiskNumber $DiskNumber -Size $ThirdSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel "Vol A" -Confirm:$false -ErrorAction Stop | Out-Null
                New-Partition -DiskNumber $DiskNumber -Size $ThirdSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel "Vol B" -Confirm:$false -ErrorAction Stop | Out-Null
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop | 
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel "Vol C" -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Verbose "All partitions were created successfully."
            }
        }
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
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

.EXAMPLE
PS> Initialize-DiskLayout -DiskNumber 2 -FileSystem NTFS -PartitionCount 2

Initializes disk 2, converts it to GPT if required, creates two partitions, and formats both partitions using NTFS.

.NOTES
This is the main function of the script. It validates the selected disk and orchestrates the entire disk initialization workflow.
#>
function Initialize-DiskLayout{
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
        [Int32]$PartitionCount
    )
    if ($PSCmdlet.ShouldProcess("Disk $DiskNumber", "Initialize disk layout")){
        try{
            $DiskInfo = Get-Disk -Number $DiskNumber -ErrorAction Stop
        }       catch{
            throw "The specified disk could not be found. $_"
            return
        }
        if($DiskInfo.IsSystem -eq $true){
            Write-Error "The selected disk contains the operating system and cannot be modified."
            return
        }
        Clear-DiskPartitions `
            -DiskNumber $DiskNumber
            
        Initialize-DiskPartitionStyle `
            -DiskNumber $DiskNumber

        New-DiskPartitions `
            -DiskNumber $DiskNumber `
            -FileSystem $FileSystem `
            -PartitionCount $PartitionCount
        }
}
Export-ModuleMember -Function Initialize-DiskLayout
