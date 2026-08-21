function Start-PartitionTool {
<#
.SYNOPSIS
Displays the available disks before starting the partition workflow.

.DESCRIPTION
Lists the disks and then invokes Initialize-PartitionTool. Use this function when you want to
review the available disks before PowerShell requests the mandatory parameters.

.PARAMETER DiskNumber
Specifies the number of the disk to process. If omitted, PowerShell requests it after listing
the available disks.

.PARAMETER FileSystem
Specifies the file system to use: NTFS or exFAT. If omitted, PowerShell requests it after
listing the available disks.

.PARAMETER PartitionCount
Specifies the number of partitions to create, from one to two. If omitted, PowerShell
requests it after listing the available disks.

.PARAMETER NewName
Specifies the file system label for the new partitions.

.PARAMETER Force
Allows processing a disk marked as a system or boot disk.

.EXAMPLE
PS> Start-PartitionTool

Displays the disks and starts the interactive parameter prompt.

.EXAMPLE
PS> Start-PartitionTool -Verbose

Displays the disks, requests the mandatory parameters, and shows detailed progress messages.

.EXAMPLE
PS> Start-PartitionTool -WhatIf

Displays the disks, requests the mandatory parameters, and previews the operations without
modifying the selected disk.

.EXAMPLE
PS> Start-PartitionTool -DiskNumber 2 -FileSystem NTFS -PartitionCount 2 -NewName Data -Force

Displays the disks and initializes disk 2 with two NTFS partitions labelled Data. The Force
switch allows processing a system or boot disk after explicit verification.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [ValidateSet('exFAT', 'NTFS')]
        [String]$FileSystem,

        [ValidateRange(1, 2)]
        [Int32]$PartitionCount,

        [String]$NewName,

        [Switch]$Force
    )
    try{
        Get-Disk -ErrorAction Stop | Format-Table
        Initialize-PartitionTool @PSBoundParameters
    }   catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Initialize-PartitionTool {
<#
.NOTES
This is an internal implementation function called by Start-PartitionTool. It orchestrates
validation, clearing, partition style configuration, partition creation, and formatting.
The selected disk must not contain the operating system. Existing data on the selected disk is removed.
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Parameter(Mandatory = $true)]
        [ValidateSet('exFAT', 'NTFS')]
        [String]$FileSystem,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 2)]
        [Int32]$PartitionCount,

        [String]$NewName,

        [Switch]$Force
    )
    $DiskInfo = Test-DiskReady -DiskNumber $DiskNumber -Force:$Force
    $Target = "Disk $($DiskInfo.Number) - $($DiskInfo.FriendlyName) - $([math]::Round($DiskInfo.Size / 1GB, 2)) GB"
    if ($PSCmdlet.ShouldProcess("$Target", "Clear, partition and format as $FileSystem")) {
        try {
            Initialize-ClearPartitions `
                -DiskNumber $DiskNumber `
                -Force:$Force
        
            Initialize-StylePartition `
                -DiskNumber $DiskNumber

            Initialize-NewPartitions `
                -DiskNumber $DiskNumber `
                -FileSystem $FileSystem `
                -PartitionCount $PartitionCount `
                -NewName $NewName
        }   catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
function Test-DiskReady {
<#
.NOTES
Validates that the selected disk exists and is safe to modify. System and boot disks are
blocked unless Force is specified; read-only and clustered disks remain blocked.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Switch]$Force
    )
    try {
        $DiskInfo = Get-Disk -Number $DiskNumber -ErrorAction Stop
    }   catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    if (-not $Force -and $DiskInfo.IsSystem) {
        throw "The selected disk contains the operating system and cannot be modified."
    }
    if (-not $Force -and $DiskInfo.IsBoot) {
        throw "The selected disk contains the boot partition and cannot be modified."
    }
    if ($DiskInfo.IsReadOnly) {
        throw "The selected disk is read-only and cannot be modified."
    }
    if ($DiskInfo.IsClustered) {
        throw "The selected disk belongs to a cluster and cannot be modified."
    }
    return $DiskInfo
}
function Initialize-ClearPartitions {
<#
.NOTES
Brings the selected disk online when necessary and removes its existing data and OEM
partitions. This is a destructive operation and supports WhatIf and confirmation handling.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Switch]$Force
    )
    $DiskInfo = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
    try {
        if ($DiskInfo.IsOffline) {
            Write-Verbose "Bringing disk $DiskNumber online..."
            $DiskInfo | Set-Disk -IsOffline $false -ErrorAction Stop | Out-Null
        }   else {
            Write-Verbose "Disk $DiskNumber is already online."
        }
    }   catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    try {
        Write-Verbose "Removing the partitions..."
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
    }   catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Initialize-StylePartition {
<#
.NOTES
Configures the selected disk to use the GPT partition style. RAW and Unknown disks are
initialized, MBR disks are converted, and disks already using GPT are left unchanged.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber
    )
    try {
        switch ((Get-Disk -Number $DiskNumber -ErrorAction Stop).PartitionStyle) {
            'RAW' {
                Write-Verbose "Initializing the disk using the GPT partition style."
                Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop | Out-Null
            }
            'Unknown' {
                Write-Verbose "Initializing the disk using the GPT partition style."
                Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction Stop | Out-Null
            }
            'MBR' {
                Write-Verbose "Converting the partition style from MBR to GPT."
                Get-Disk -Number $DiskNumber | Set-Disk -PartitionStyle GPT -ErrorAction Stop | Out-Null
            }
            'GPT' {
                Write-Verbose "The disk already uses the GPT partition style."
            }
        }
    }   catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Initialize-NewPartitions {
<#
.NOTES
Creates and formats one or two partitions on the selected disk. Two partitions divide the
disk approximately in half, and the selected file system and label are applied to each one.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 10)]
        [Int32]$DiskNumber,

        [Parameter(Mandatory = $true)]
        [ValidateSet('exFAT', 'NTFS')]
        [String]$FileSystem,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 2)]
        [Int32]$PartitionCount,

        [String]$NewName
    )
    $DiskSize = (Get-Disk -Number $DiskNumber -ErrorAction Stop).Size
    $HalfSize = [math]::Floor($DiskSize / 2)
    if ($FileSystem -eq "exFAT") {
        if ($NewName.length -gt 11) {
            throw "You cannot enter more than 11 characters for the label in the exFat format."
        }
    }
    try {
        switch ($PartitionCount) {
            1 {
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop | 
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $NewName -ErrorAction Stop | Out-Null
                Write-Verbose "Partition created successfully."
            }
            2 {
                New-Partition -DiskNumber $DiskNumber -Size $HalfSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $NewName -ErrorAction Stop | Out-Null
                New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop |
                    Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $NewName -ErrorAction Stop | Out-Null
                Write-Verbose "Both partitions were created successfully."
            }
        }
    }   catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
Export-ModuleMember -Function Start-PartitionTool
