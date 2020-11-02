
#
# Pieter De Ridder
# Create a new webserver plugin (Powershell Module).
#
# created : 02/11/2020
# changed : 02/11/2020
#

# global vars
$global:WorkFolder = $($PSScriptRoot)
$global:WebPluginsPath = "$($global:WorkFolder)\plugins"

# create plugins folder
If (-Not (Test-Path $global:WebPluginsPath)) {
    New-Item $global:WebPluginsPath -ItemType Directory
}

[string]$NewPluginName = Read-Host -Prompt "Enter Webserver Plugin Name"

# create module manifest file
If (-Not (Test-Path "$($global:WebPluginsPath)\$($NewPluginName)")) {
    New-Item "$($global:WebPluginsPath)\$($NewPluginName)" -ItemType Directory
    
    [string]$manifestFilename = "$($global:WebPluginsPath)\$($NewPluginName)\$($NewPluginName).psd1"
    [string]$moduleFilename = "$($global:WebPluginsPath)\$($NewPluginName)\$($NewPluginName).psm1"
    [string]$guid = $(New-Guid)

    # create the meta file
    $params = @{
        Path = $manifestFilename
        RootModule = $(Split-Path $moduleFilename -Leaf)
        ModuleVersion = '0.1.0'
        Guid = $guid
        Author = $($env:USERNAME)
        Description = 'Webserver Plugin'
        #RequiredModules = @("KWS.Global")
    }
    New-ModuleManifest @params

    # create empty module file
    New-Item -Path $moduleFilename -ItemType File

    # add some content already
    Add-Content -Path $moduleFilename -Value '# My Webserver plugin'
    Add-Content -Path $moduleFilename -Value ''
    Add-Content -Path $moduleFilename -Value '$CommandsToExport = @()'
    Add-Content -Path $moduleFilename -Value ''
    Add-Content -Path $moduleFilename -Value 'Function Invoke-HelloWorld {'
    Add-Content -Path $moduleFilename -Value '  Write-Output "Hello"'
    Add-Content -Path $moduleFilename -Value '}'
    Add-Content -Path $moduleFilename -Value '$CommandsToExport += "Invoke-HelloWorld"'
    Add-Content -Path $moduleFilename -Value ''
    Add-Content -Path $moduleFilename -Value ''
    Add-Content -Path $moduleFilename -Value 'Export-ModuleMember -Function $CommandsToExport'
    Add-Content -Path $moduleFilename -Value ''

    Write-Host "Webserver Plugin created"
} else {
    Write-Warning "Webserver Plugin with same name already present!"
    Exit(-1)
}

Exit(0)