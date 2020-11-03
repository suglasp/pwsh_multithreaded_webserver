
#
# Pieter De Ridder
# Bootstrap script for webserver instances (Powershell) and Loadbalancer (Nginx)
#
# created : 01/11/2020
# changed : 03/11/2020
#
# Only tested on Windows 10 and Server 2019 with Poweshell 5.1 and Powershell 7.0.3.
# Currently will not run on Linux, unless you change $global:PowershellExe and $global:NginxExe.
#
# Usage:
# pwsh_webserver_bootstrap.ps1 [-start] [-stop] [-reload] [-verify] [-error] [-access] [-config]
#
# -start  : start nginx and powershell webserver instances
# -stop   : stop nginx and powershell webserver instances
# -reload : start + stop
# -verify : check if all is online
# -error  : dump last 20 lines of nginx error.log
# -access : dump last 20 lines of nginx access.log
# -config : dump nginx nginx.conf
#
# The purpose is the nginx (loadbalancer) is accessible from outside, and eventually does loadbalancing and SSL termination.
# The Powershell web instances are hosted on localhost, so only Nginx can "talk" in the backend to the Powershell web instances.
#



$ProgressPreference = "SilentlyContinue"

# global vars
[string]$global:WorkFolder = $PSScriptRoot
[string]$global:LoadbalancerPath = "$($global:WorkFolder)\loadbalancer"
[string]$global:LoadbalancerPIDFile = "$($global:LoadbalancerPath)\logs\nginx.pid"
[string]$global:LoadbalancerCfgFile = "$($global:LoadbalancerPath)\conf\nginx.conf"
[string]$global:LoadbalancerAccLog = "$($global:LoadbalancerPath)\logs\access.log"
[string]$global:LoadbalancerErrLog = "$($global:LoadbalancerPath)\logs\error.log"
[string]$global:WebLogsPath = "$($global:WorkFolder)\logs"
[int32]$global:WebStartPort = 8080
[int32]$global:WebCount = 2
[int32]$global:LoadbalancerStartPort = 80
[int32]$global:LoadbalancerStartPortSSL = 443
[bool]$global:LoadbalancerUseSSL = $false
[string]$global:PowershellExe = "powershell.exe"
[string]$global:NginxExe = "nginx.exe"


#
# Function : Start-Loadbalancer
#
Function Start-Loadbalancer {

    # readyness for Powershell Core edition
    If ($PSVersionTable.PSEdition -eq "Core") {
        [string]$global:PowershellExe = "pwsh.exe"
        [string]$global:NginxExe = "nginx.exe"
    }

    # start web instances
    Write-Host "* Starting web instances..."
    For([int32]$port = $global:WebStartPort; $port -lt ($global:WebStartPort + $global:WebCount); $port++) {
        Write-Host "  Instance : $($port.ToString())"
        # could also be done through runspaces. Keep it simple.
        Start-Process -FilePath "$($global:PowershellExe)" -ArgumentList "-ExecutionPolicy ByPass -File $($global:WorkFolder)\pwsh_webserver_instance.ps1 -port $($port.ToString())" -WorkingDirectory "$($global:WorkFolder)" -WindowStyle Minimized
        
        Start-Sleep -Seconds (1 * $global:WebCount)
    }

    # start loadbalancer
    Write-Host "* Starting loadbalancer..."
    If (@(Get-Process -Name "nginx" -ErrorAction SilentlyContinue).Count -eq 0) {
        # allow Loadbalancer Windows firewall rule
        New-NetFirewallRule -DisplayName "webserver_loadbalancer_http" -Profile @('Domain', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @($global:LoadbalancerStartPort) -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "webserver_loadbalancer_https" -Profile @('Domain', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @($global:LoadbalancerStartPortSSL) -ErrorAction SilentlyContinue

        # start loadbalancer process(es)
        Start-Process -FilePath "$($global:LoadbalancerPath)\$($global:NginxExe)" -WorkingDirectory "$($global:LoadbalancerPath)" -WindowStyle Minimized
    } else {
        Write-Warning "already running"
    }

    # verify, first wait a short amount to give webservers a head start
    Write-Host ""
    Start-Sleep -Seconds ((2 * $global:WebCount) + 4)
    Verify-Loadbalancer


    # show part of error log
    Dump-Logfile -logfile $global:LoadbalancerErrLog -linecount 3

    # show part of access log
    Dump-Logfile -logfile $global:LoadbalancerAccLog -linecount 3
}

#
# Function : Stop-Loadbalancer
#
Function Stop-Loadbalancer {
    # stop loadbalancer
    Write-Host "* Stopping loadbalancer..."
    $processesLoadBalancer = @(Get-Process -Name "nginx" -ErrorAction SilentlyContinue)

    If ($processesLoadBalancer.Count -gt 0) {
        # stop loadbalancer processes
        ForEach($nginx in $processesLoadBalancer) {
            #$nginx.Close()
            #$nginx.Kill()

            Stop-Process -Id $nginx.Id
        }

        # remove .pid file
        If (Test-Path -Path $global:LoadbalancerPIDFile) {
            Remove-Item -Path $global:LoadbalancerPIDFile -ErrorAction SilentlyContinue
        }

        # remove loadbalancer Windows firewall rule
        Remove-NetFirewallRule -DisplayName "webserver_loadbalancer_http" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "webserver_loadbalancer_https" -ErrorAction SilentlyContinue
    } else {
        Write-Warning "no instances running"
    }

    Start-Sleep -Seconds 1

    # stop webservers
    Write-Host "* Stopping web instances..."
    $processesWebservers = @(Get-Process -Name "powershell" -ErrorAction SilentlyContinue)

    If ($processesWebservers.Count -gt 0) {
        For([int32]$port = $global:WebStartPort; $port -lt ($global:WebStartPort + $global:WebCount); $port++) {
            Write-Host "  Instance : $($port.ToString()) ... " -NoNewline
            Invoke-WebRequest -Uri "http://localhost:$($port.ToString())/kill" -TimeoutSec 5
            Start-Sleep -Seconds (1 * $global:WebCount)
        }
    } else {
        Write-Warning "already stopped"
    }
}


#
# Function : Reload-Loadbalancer
#
Function Reload-Loadbalancer {
    Stop-Loadbalancer

    Start-Sleep -Seconds 2

    Start-Loadbalancer
}


#
# Function : Verify-Loadbalancer
#
Function Verify-Loadbalancer {
    Write-Host " Verify Loadbalancer port test ... " -NoNewline

    # default http
    [string]$loadbalancerProtocol = "http"
    [uint32]$loadbalancerPort = $global:LoadbalancerStartPort

    # make it https
    If ($global:LoadbalancerUseSSL) {
        $loadbalancerProtocol += "s"
        $loadbalancerPort = $global:LoadbalancerStartPortSSL
    }

    If ($(Invoke-WebRequest -Uri "$($loadbalancerProtocol)://$([environment]::GetEnvironmentVariable("COMPUTERNAME")):$($loadbalancerPort)" -TimeoutSec 5).StatusCode -eq 200) {
       Write-Host "OK"
    } else {
        Write-Host "Not OK"
    }

    # backend is always http
    For([int32]$port = $global:WebStartPort; $port -lt ($global:WebStartPort + $global:WebCount); $port++) {
        Write-Host " Verify Instance port test : $($port.ToString()) ... " -NoNewline
        If ($(Invoke-WebRequest -Uri "http://127.0.0.1:$($port.ToString())/ping" -TimeoutSec 5).StatusCode -eq 200) {
            Write-Host "OK"
        } else {
            Write-Host "Not OK"
        }
    }
}

#
# Function : Dump-Logfile
#
Function Dump-Logfile {
    Param(
        [string]$logfile,
        [int32]$linecount = 10
    )

    If (Test-Path -Path $logfile) {
        Write-Host ""
        Write-Host "-- last $($linecount.ToString()) lines of $(Split-Path -Path $logfile -Leaf)"
        Get-Content -Path $logfile | Select -First $linecount
    } else {
        Write-Warning "File $($logfile) not found."
    }
}

#
# Function : Dump-Cfgfile
#
Function Dump-Cfgfile {
    Param(
        [string]$cfgfile
    )

    If (Test-Path -Path $cfgfile) {
        Write-Host ""
        Write-Host "-- config file $(Split-Path -Path $cfgfile -Leaf)"
        Get-Content -Path $cfgfile
    } else {
        Write-Warning "File $($cfgfile) not found."
    }
}

#
# Function Main
#
Function Main {
    Param (
        [System.Array]$Arguments
    )
    
    # extract arguments
    If ($Arguments) {
        for($i = 0; $i -lt $Arguments.Length; $i++) {
            # A pwsh Switch statement is by default always case insensitive for Strings
            Switch ($Arguments[$i]) {
                "-start" {
                    Write-Host ">> Starting loadbalancer"                
                    Start-Loadbalancer         
                }

                "-stop" {
                    Write-Host ">> Stopping loadbalancer"
                    Stop-Loadbalancer
                }

                "-reload" {                
                    Write-Host ">> Reloading loadbalancer"
                    Reload-Loadbalancer
                }

                "-verify" {                
                    Write-Host ">> Verify loadbalancer"
                    Verify-Loadbalancer
                }                

                "-access" {
                    Write-Host ">> Access log file"      
                    Dump-Logfile -logfile $global:LoadbalancerAccLog -linecount 20
                }

                "-error" { 
                    Write-Host ">> Error log file"  
                    Dump-Logfile -logfile $global:LoadbalancerErrLog -linecount 20
                }

                "-config" {
                    Write-Host ">> Config file" 
                    Dump-Cfgfile -cfgfile $global:LoadbalancerCfgFile
                }
            }
        }
    } else {
        Write-Host "Usage : -start, -stop, -reload, -verify, -access or -error"
    }

    Exit(0)
}



# -------------------------------------------


# Call Main C-style function
Main -Arguments $args

