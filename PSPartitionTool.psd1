@{
    RootModule            = 'PSPartitionTool.psm1'
    ModuleVersion         = '1.0'
    GUID                  = 'e3c2a1f4-8b9d-4c7e-9f2d-1a2b3c4d5e6f'
    Author                = 'AraMaster-bit'
    PowerShellVersion     = '5.1', '7.6.4'
    CompatiblePSEditions  = @('Desktop', 'Core')
    Description           = 'Disk Partitioning Tools.'
    FunctionsToExport     = @(
        'Initialize-DiskLayout'
    )
    RequiredModules       = @()
}
