@{
    RootModule            = 'PSPartitionTool.psm1'
    ModuleVersion         = '0.1.2'
    GUID                  = 'c3a691d4-9271-4183-8e8d-cf55d1fbf67e'
    Author                = 'AraMaster-bit'
    PowerShellVersion     = '5.1'
    CompatiblePSEditions  = @('Desktop', 'Core')
    Description           = 'PowerShell module for automated disk preparation, GPT initialization, partition creation, and filesystem formatting.'
    FunctionsToExport     = @(
        'Start-PartitionTool'
    )
    RequiredModules       = @()
}

