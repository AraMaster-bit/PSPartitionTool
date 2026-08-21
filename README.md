# PSPartitionTool

PowerShell module for preparing non-system disks. It removes existing partitions, configures GPT,
and creates one or two NTFS or exFAT partitions.

> WARNING: The selected disk is erased. Verify the disk number before continuing.

## Usage

Import the module and execute its public function:

```powershell
Import-Module .\PSPartitionTool.psd1
Start-PartitionTool
```

`Start-PartitionTool` displays the available disks and then invokes the internal partition
workflow. PowerShell requests the mandatory parameters after displaying the disks. The selected
disk is erased, so verify the disk number before continuing.

You can also provide the parameters directly:

```powershell
Start-PartitionTool -DiskNumber 2 -FileSystem NTFS -PartitionCount 2 -NewName Data -Verbose
```

Use `-Force` only after verifying that the selected system or boot disk can be erased. Use
`-WhatIf` to preview the operation without modifying the disk.

## Requirements

- Windows 10, Windows 11, or Windows Server.
- PowerShell 5.1 or PowerShell 7.
- Administrator privileges.

## Installation

Clone the repository:

```powershell
git clone https://github.com/AraMaster-bit/PSPartitionTool.git
