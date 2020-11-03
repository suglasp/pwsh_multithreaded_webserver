
#
# Pieter De Ridder
# Quick and dirty script to kill Powershell webserver instance directly
# In Powershell ISE, run this in a seperated Tab (or powershell session for that matter) to kill the running web instance.
#
# created : 02/11/2020
# changed : 03/11/2020
#


[uint32]$port = 8080

try {
    Invoke-WebRequest -Uri "http://localhost:$($port.ToString())/kill" -TimeoutSec 5
} catch {
    Write-Host "OK"
}

Remove-NetFirewallRule -DisplayName "webserver_$($global:Port)" -ErrorAction SilentlyContinue

Exit(0)