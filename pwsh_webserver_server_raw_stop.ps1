
#
# Pieter De Ridder
# Quick and dirty script to kill Powershell webserver instance directly
# In Powershell ISE, run this in a seperated Tab (or powershell session for that matter) to kill the running web instance.
#
# created : 02/11/2020
# changed : 05/11/2020
#


#
# -- Script for use during development of the pwsh_webserver_instance.ps1 or for development of Plugins
#



#region Global vars
# -- ( vars should be same as in pwsh_webserver_instance.ps1 )
[string]$global:WorkFolder = $PSScriptRoot
[string]$global:WebPluginsPath = "$($global:WorkFolder)\plugins"
[UInt32]$global:Port = 8080
#endregion


# try stopping webserver
Write-Host ""
try {
    Invoke-WebRequest -Uri "http://localhost:$($port.ToString())/kill" -TimeoutSec 5
} catch {
    Write-Host "OK"
}

# cleanup firewall port
Remove-NetFirewallRule -DisplayName "webserver_$($global:Port)" -ErrorAction SilentlyContinue

Exit(0)