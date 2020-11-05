
#
# Pieter De Ridder
# Powershell webserver single instance
#
# created : 01/11/2020
# changed : 05/11/2020
#
# Only tested on Windows 10 and Server 2019 with Poweshell 5.1 and Powershell 7.0.3.
# This script is written with cross platform in mind.
#


#region Global vars
[string]$global:WorkFolder = $PSScriptRoot
[string]$global:ContentFolder = "$($global:WorkFolder)\content"
[string]$global:WebPluginsPath = "$($global:WorkFolder)\plugins"
[string]$global:WebLogsPath = "$($global:WorkFolder)\logs"
[UInt32]$global:Port = 8080
[UInt32]$global:ExitCode = 0
[System.Net.HttpListener]$global:Http = [System.Net.HttpListener]::new()
[bool]$global:PublishLocalhost = $true
[bool]$global:DebugExtraVerbose = $false
[string]$global:IndexPage = "index.html"
#endregion



#region Helper Functions
#
# Function : Start-Webserver
#
Function Start-Webserver {
    Param (
        [System.Array]$ServerUrlPrefixes = @("localhost", "127.0.0.1", "[::1]"),
        [UInt16]$ServerPort = 8080,
        [System.Net.AuthenticationSchemes]$Authentication = [System.Net.AuthenticationSchemes]::Anonymous
    )

    # create http in memory if not exists
    If (-not ($global:Http)) {
        $global:Http = [System.Net.HttpListener]::new()
    }

    # pre-load plugins
    DynamicLoad-WebPlugins

    # try starting the  http server
    If ($global:Http) {
        # Hostname and ports to listen on
        ForEach($ServerURLPrefix in $ServerUrlPrefixes) {
            $global:Http.Prefixes.Add("http://$($ServerURLPrefix):$($ServerPort)/")
        }

        # set authentication
        $global:Http.AuthenticationSchemes = $Authentication

        try {
            # try starting the http server
            $global:Http.Start()

            # Log ready message to terminal 
            If ($global:Http.IsListening) {
                Write-Host "[!] HTTP Server is hosting"
                ForEach($ServerURLPrefix in $ServerUrlPrefixes) {
                    Write-Host " -> Serving URL http://$($ServerURLPrefix):$($ServerPort)/"
                }

                # allow Windows firewall rule
                New-NetFirewallRule -DisplayName "webserver_$($global:Port)" -Profile @('Domain', 'Private', 'Public') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @($global:Port) -ErrorAction SilentlyContinue
            } Else {
                Write-Host "[!] HTTP Server has soft failed"
                #$global:Http.Close()
                $global:Http.Stop()
                
                Exit-Bailout
            }
        } catch [System.Net.HttpListenerException] {
            Write-Host "[!] HTTP Server has hard failed"
        }
    }
}


#
# Function : Stop-Webserver
#
Function Stop-Webserver {
    # shutdown http server
    If ($global:Http.IsListening) {
		#$global:Http.Close()
        $global:Http.Stop()
        $global:Http = $null
    }

    # remove Windows firewall rule
    Remove-NetFirewallRule -DisplayName "webserver_$($global:Port)" -ErrorAction SilentlyContinue
}

#
# Function : Exit-Gracefully
#
Function Exit-Gracefully {
    # shutdown http server
    Stop-Webserver

    # unload plugins
    DynamicUnload-WebPlugins

    # stop logging
    Stop-LocalLogging

    # exit nicely
    $global:ExitCode = 0
    Exit($global:ExitCode)
}

#
# Function : Exit-Bailout
#
Function Exit-Bailout {
    # shutdown http server
    Stop-Webserver

    # unload plugins
    DynamicUnload-WebPlugins

    # stop logging
    Stop-LocalLogging

    # exit with some error
    $global:ExitCode = -1
    Exit($global:ExitCode)
}

#
# Function : DynamicLoad-WebPlugins
#
Function DynamicLoad-WebPlugins {
    Write-Host ""
    Write-Host "Preparing plugins..."

    # set Webserver plugin Path
    If (-not ($env:PSModulePath.Contains($global:WebPluginsPath))) {
        #$env:PSModulePath += ";" + $global:WebPluginsPath

        $pathPSModulesTemp = [Environment]::GetEnvironmentVariable("PSModulePath")
        $pathPSModulesTemp += ";" + $global:WebPluginsPath
        [Environment]::SetEnvironmentVariable("PSModulePath", $pathPSModulesTemp)
    }

    # dynamic load webserver plugins
    $pluginsList = @(Get-Module -ListAvailable)

    ForEach($plugin in $pluginsList) {
        If ($plugin.ModuleBase.Contains($global:WebPluginsPath)) {
            # If not already loaded, do load it!
            If (-not (Get-Module -Name $($plugin.Name))) {
                Write-Host "[!] Loading plugin : $($plugin.Name)"
                Import-Module -Name $($plugin.Name) -Scope Local -DisableNameChecking
            } Else {
                Write-Host "[i] Plugin already present : $($plugin.Name) (some plugins have a dependency and are auto loaded)"
            }
        }
    }

    Write-Host ""
}

#
# Function : DynamicUnload-WebPlugins
#
Function DynamicUnload-WebPlugins {
    Write-Host ""
    Write-Host "Unloading plugins..."

    # dynamic unload webserver plugins
    $pluginsListLoaded = @(Get-Module)

    ForEach($plugin in $pluginsListLoaded) {
        If ($plugin.ModuleBase.Contains($global:WebPluginsPath)) {
            Write-Host "[!] Unloading plugin : $($plugin.Name)"
            Remove-Module -Name $($plugin.Name) -Force
        }
    }

    Write-Host ""
}

#
# Function : Start-LocalLogging
#
Function Start-LocalLogging
{
    # create logs path if not exists
    If (-Not (Test-Path -Path $global:WebLogsPath)) {
        New-Item -Name $global:WebLogsPath -ItemType Directory
    }

    # try enable logging output
    If (Test-Path -Path $global:WebLogsPath) {
        Start-Transcript -OutputDirectory $global:WebLogsPath | Out-Null
    }
}

#
# Function : Stop-LocalLogging
#
Function Stop-LocalLogging
{
    If (Test-Path -Path $global:WebLogsPath) {
        Stop-Transcript
    }
}
#endregion


#region Main function
#
# Function : Main
#
Function Main {
    Param (
        [System.Array]$Arguments
    )

    # clear screen if needed
    Clear-Host

    # enable logging
    Start-LocalLogging

    # output working folder
    Write-Host "Workdir : $($global:WorkFolder)"

    # extract custom port if requested
    If ($Arguments) {
        for($i = 0; $i -lt $Arguments.Length; $i++) {
            # default, a pwsh Switch statement on a String is always case insensitive
            Switch ($Arguments[$i]) {
                "-port" {                
                    If (($i +1) -le $Arguments.Length) {
                        $global:Port = $Arguments[$i +1]
                    }
                }
            }
        }
    }

    # try starting the http webserver
    If ($global:PublishLocalhost) {
        # localhost only hosting
        Start-Webserver -ServerPort $global:Port
    } Else {
        # public hosting
        Start-Webserver -ServerUrlPrefixes @("*") -ServerPort $global:Port
    }


    # start listening loop
    If ($global:Http) {
        While ($global:Http.IsListening) {

            # Get Request Url
            # When a request is made in a web browser the GetContext() method will return a request object
            $context = $global:Http.GetContext()

            #$context.Request.Url | Select -Property *
            #AbsolutePath   : /styles.css
            #AbsoluteUri    : http://localhost:8080/styles.css?v=1.0
            #LocalPath      : /styles.css
            #Authority      : localhost:8080
            #HostNameType   : Dns
            #IsDefaultPort  : False
            #IsFile         : False
            #IsLoopback     : True
            #PathAndQuery   : /styles.css?v=1.0
            #Segments       : {/, styles.css}
            #IsUnc          : False
            #Host           : localhost
            #Port           : 8080
            #Query          : ?v=1.0
            #Fragment       : 
            #Scheme         : http
            #OriginalString : http://localhost:8080/styles.css?v=1.0
            #DnsSafeHost    : localhost
            #IdnHost        : localhost
            #IsAbsoluteUri  : True
            #UserEscaped    : False
            #UserInfo       :

            #AbsolutePath   : /someapp/someapp.html
            #AbsoluteUri    : http://localhost:8080/someapp/someapp.html
            #LocalPath      : /someapp/someapp.html
            #Authority      : localhost:8080
            #HostNameType   : Dns
            #IsDefaultPort  : False
            #IsFile         : False
            #IsLoopback     : True
            #PathAndQuery   : /someapp/someapp.html
            #Segments       : {/, someapp/, someapp.html}
            #IsUnc          : False
            #Host           : localhost
            #Port           : 8080
            #Query          : 
            #Fragment       : 
            #Scheme         : http
            #OriginalString : http://localhost:8080/someapp/someapp.html
            #DnsSafeHost    : localhost
            #IdnHost        : localhost
            #IsAbsoluteUri  : True
            #UserEscaped    : False
            #UserInfo       : 

            # timestamp info of the request
            [string]$requestTimeStamp = $(Get-Date).ToString("dd-MM-yyyy@HH:mm:ss")

            # write out we have incoming a request
            Write-Host ""
            Write-Host "** [$($requestTimeStamp)] Request : $($context.Request.UserHostAddress)  =>  $($context.Request.Url)"
            Write-Host "   -> Page : $($context.Request.Url.AbsolutePath)"
            Write-Host ""

            # extra verbose for troubleshooting or debugging
            If ($global:DebugExtraVerbose) {
                Write-Host "-- VERBOSE --"
                Write-Host "AbsUri      : $($context.Request.Url.AbsoluteUri)"
                Write-Host "RawUrl Path : $($context.Request.RawUrl)"
                Write-Host "Abs Path    : $($context.Request.Url.AbsolutePath)"
                Write-Host "Local Path  : $($context.Request.Url.LocalPath)"
                Write-Host "Referral : $($context.Request.UrlReferrer)"
                Write-Host "-- VERBOSE --"
            }

            # kill webserver
            # http://127.0.0.1/kill'
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/kill') {
                Write-Host "[!] HTTP Server going down!"
                $context.Response.StatusCode = [int32][System.Net.HttpStatusCode]::GatewayTimeout
                $context.Response.StatusDescription = "Gateway timeout"
                $context.Response.Close()

                Start-Sleep -Seconds 1

                Exit-Gracefully
            }

            # webserver ping
            # http://127.0.0.1/ping'
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/ping') {
                Write-Host "[!] Webserver Ping, sending pong"
                [string]$pingResponse = "<html><head><title>ping</title><body>Received Ping. Return Pong.</body></html>"

                #resposed to the request
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($pingResponse)
                $context.Response.Headers.Add("Content-Type","text/html")
                $context.Response.StatusCode = [int32][System.Net.HttpStatusCode]::OK
                $context.Response.StatusDescription = "PING OK"
                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                $context.Response.OutputStream.Close()
                
                Continue          
            }
                        

            # webserver cookie
            # http://127.0.0.1/cookie'
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/cookie') {
                Write-Host "[!] Webserver cookie"
                [string]$cookieResponse = "<html><head><title>cookie</title><body>Cookies!</body></html>"

                # ---- read cookie(s)
                [System.Net.Cookie]$getCookie = Get-WebCookie -Context $context -CookieSearchID "ID"

                If ($getCookie) {
                    Write-Host "Found cookie : $($getCookie.Name) = $($getCookie.Value)"
                } Else {
                    Write-Host "No cookie found with name $([char](34))ID$([char](34))"
                }
                # ---- read cookie(s)

                #respose to the request
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($cookieResponse)
                $context.Response.Headers.Add("Content-Type","text/html")
                $context.Response.StatusCode = [int32][System.Net.HttpStatusCode]::OK
                $context.Response.StatusDescription = "COOKIES OK"                

                # ---- write a cookie                
                If ($getCookie) {
                    # if exists, clear cookie
                    Clear-WebCookie -Context $context -CookieID "ID"
                } Else {
                    # if not exitst, make cookie
                    Set-WebCookie -Context $context -CookieID "ID" -CookieValue "$([Environment]::GetEnvironmentVariable("USERNAME"))"
                }
                # ---- write a cookie

                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                $context.Response.OutputStream.Close()        
                
                Continue
            }


            # Request root and other files
            # http://127.0.0.1/<filename>.<ext>
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -like "/*") {
                # if we're at root '/' then replace with '/index.html'. Otherwise, extract pagename.
                [string]$requestedFilename = ""
                
                # load a file (contains '.' like ../file.css or ../file.html)
                If ($context.Request.Url.AbsolutePath.Contains('.')) {
                    $requestedFilename = $context.Request.Url.AbsolutePath
                } Else {
                    # fix all lose ends in a URL to we fallback to safety
                    If ($context.Request.Url.AbsolutePath.EndsWith('/')) {
                        $requestedFilename = $context.Request.Url.AbsolutePath + $global:IndexPage
                    } Else {
                        # if there is no ending slash in the provided Url, try redirecting to the full url + index page.
                        $redirectUrl = $context.Request.Url.AbsolutePath + "/" + $global:IndexPage
                        Start-WebRedirect -Context $context -RelativeUrl $redirectUrl
                        Continue
                    }
                }
 
                # build local path for serving.
                # Replace forward slash with back slash on Windows. On Linux it will stay the same.
                [string]$pagetoload = "$($global:ContentFolder)$($requestedFilename.Replace("/", [IO.Path]::DirectorySeparatorChar))"
                
                If (-not([string]::IsNullOrEmpty($pagetoload)) -and ($pagetoload.Contains('.'))) {
                    Write-Host "requested Filename : $($requestedFilename)"
                    Write-Host "Page to load : $($pagetoload)"

                    If (Test-Path -Path $pagetoload) {
                        #[string]$somefile = Get-Content -Path $pagetoload -Raw
                        #$buffer = [System.Text.Encoding]::UTF8.GetBytes($somefile)

                        $buffer = [System.IO.File]::ReadAllBytes($pagetoload)
                        $requestedFilename
                        Switch -wildcard ($requestedFilename) {
                            "*.htm" { $context.Response.Headers.Add("Content-Type","text/html") }
                            "*.html" { $context.Response.Headers.Add("Content-Type","text/html") }
                            "*.css" { $context.Response.Headers.Add("Content-Type","text/css") }
                            "*.csv" { $context.Response.Headers.Add("Content-Type","text/csv") }
                            "*.txt" { $context.Response.Headers.Add("Content-Type","text/plain") }
                            "*.xml" { $context.Response.Headers.Add("Content-Type","text/xml") }
                            "*.js" { $context.Response.Headers.Add("Content-Type","text/javascript") }
                            "*.ico" { $context.Response.Headers.Add("Content-Type","image/vnd.microsoft.icon") }
                            "*.jpg" { $context.Response.Headers.Add("Content-Type","image/jpeg") }
                            "*.jpeg" { $context.Response.Headers.Add("Content-Type","image/jpeg") }
                            "*.png" { $context.Response.Headers.Add("Content-Type","image/png") }
                            "*.bmp" { $context.Response.Headers.Add("Content-Type","image/bmp") }
                            "*.gif" { $context.Response.Headers.Add("Content-Type","image/gif") }
                            "*.pdf" { $context.Response.Headers.Add("Content-Type","application/pdf") }
                            "*.zip" { $context.Response.Headers.Add("Content-Type","application/zip") }
                            "*.json" { $context.Response.Headers.Add("Content-Type","application/json") }       
                            "*.7z" { $context.Response.Headers.Add("Content-Type","application/x-7z-compressed") }                        
                            "*.wav" { $context.Response.Headers.Add("Content-Type","audio/wav") }
                            "*.ttf" { $context.Response.Headers.Add("Content-Type","font/ttf") }
                            Default { $context.Response.Headers.Add("Content-Type","application/octet-stream") }                            
                        }
            
                        #$Context.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($pagetoload)
                        $context.Response.ContentLength64 = $buffer.Length
                        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) 
                        $context.Response.OutputStream.Close()
                    } Else {
                        # woops, 404                
                        $context.Response.StatusCode = [int32][System.Net.HttpStatusCode]::NotFound
                        $context.Response.StatusDescription = "Page not found"
                        $context.Response.Close()
                    }
                }

                Continue
            }

            # forms backend response (from Plugin Web.Postback)
            # http://127.0.0.1/backend/someapppost'
            If ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/backend/someapppost') {
                Invoke-ProcessPostBack -Context $context
                Continue
            }   

            Write-Host ""

            # Do not stop debugging in ISE or Powershell with VSCode
            # better redirect to http://localhost:<webserver_port>/kill" for clean shutdown

        }        
    } else {
        Write-Host "[!] Http server failed!?" -ForegroundColor "Red"
    }

    # exit Gracefully
    Exit-Gracefully
}
#endregion



# -------------------------------------------


# Call Main C-style function
Main -Arguments $args
