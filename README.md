# PSPartitionTool

PowerShell module for automated disk preparation, partition management, and filesystem initialization.

## Overview

PSPartitionTool is a PowerShell module designed to automate the preparation of non-operating system disks.

The module performs a complete disk initialization workflow:
- Validates the selected disk.
- Detects and prevents operations on disks containing the operating system.
- Removes existing partitions.
- Initializes or converts the disk to GPT partition style.
- Creates a custom partition layout.
- Formats partitions using NTFS or exFAT.

## Features

- Operating system disk detection for safety.
- Complete removal of existing partitions.
- Automatic GPT partition style configuration.
- Support for MBR to GPT conversion.
- Creation of 1 to 3 partitions.
- NTFS and exFAT filesystem support.
- PowerShell `-WhatIf` and `-Confirm` support.
- Verbose execution output.

## Requirements

- Windows 10, Windows 11, or Windows Server.
- PowerShell 5.1 or PowerShell 7.
- Administrator privileges.

## Installation

Clone the repository:

```powershell
git clone https://github.com/AraMaster-bit/PSPartitionTool.git
