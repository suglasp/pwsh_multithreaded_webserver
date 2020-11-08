
#
# Pieter De Ridder
# Powershell webserver single instance
#
# created : 01/11/2020
# changed : 08/11/2020
#
# Only tested on Windows 10 and Server 2019 with Poweshell 5.1 and Powershell 7.0.3.
# This script is written with cross platform in mind.
#


#region Global vars
[string]$global:WorkFolder = $PSScriptRoot
[UInt32]$global:Port = 8080
[UInt32]$global:ExitCode = 0
[string]$global:ContentFolder = "$($global:WorkFolder)\content"
[string]$global:WebPluginsPath = "$($global:WorkFolder)\plugins"
[string]$global:WebLogsPath = "$($global:WorkFolder)\logs"
[string]$global:WebLogFile = "$($global:WebLogsPath)\$([environment]::GetEnvironmentVariable("COMPUTERNAME").ToLowerInvariant())_$($global:port).log"
[System.Net.HttpListener]$global:Http = [System.Net.HttpListener]::new()
[bool]$global:PublishLocalhost = $true
[bool]$global:DebugVerbose = $true
[bool]$global:DebugExtraVerbose = $false
[bool]$global:DebugTransscriptLogging = $false
[string]$global:IndexPage = "index.html"
#endregion



#region Helper Functions
#
# Function : Print-Title
# Startup banner
#
Function Print-Title {
    Write-Log -LogMsg "" -LogFile $global:WebLogFile
    Write-Log -LogMsg "------------------------------------------" -LogFile $global:WebLogFile
    Write-Log -LogMsg "Powershell Web Server Instance" -LogFile $global:WebLogFile
    Write-Log -LogMsg "------------------------------------------" -LogFile $global:WebLogFile
    Write-Log -LogMsg "" -LogFile $global:WebLogFile

    # output working folder and flags
    Write-Log -LogMsg "Workdir : $($global:WorkFolder)" -LogFile $global:WebLogFile
    Write-Log -LogMsg "Verbose (stdout) : $($global:DebugVerbose.ToString())" -LogFile $global:WebLogFile
    Write-Log -LogMsg "Extra Verbose    : $($global:DebugExtraVerbose.ToString())" -LogFile $global:WebLogFile
    Write-Log -LogMsg "Transscript logs : $($global:DebugTransscriptLogging.ToString())" -LogFile $global:WebLogFile
    Write-Log -LogMsg "" -LogFile $global:WebLogFile

    If ($global:DebugVerbose) {
        Write-Log -LogMsg "[i] For performance, disable stdout output by setting DebugVerbose to $false." -LogFile $global:WebLogFile
        Write-Log -LogMsg "" -LogFile $global:WebLogFile
    }
}


#
# Function : Start-Webserver
# Init webserver instance
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
                Write-Log -LogMsg "[!] HTTP Server is hosting" -LogFile $global:WebLogFile
                ForEach($ServerURLPrefix in $ServerUrlPrefixes) {
                    Write-Log -LogMsg " -> Serving URL http://$($ServerURLPrefix):$($ServerPort)/" -LogFile $global:WebLogFile
                }

                # allow Windows firewall rule
                New-NetFirewallRule -DisplayName "webserver_$($global:Port)" -Profile @('Domain', 'Private', 'Public') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @($global:Port) -ErrorAction SilentlyContinue
            } Else {
                Write-Log -LogMsg "[!] HTTP Server has soft failed" -LogFile $global:WebLogFile
                #$global:Http.Close()
                $global:Http.Stop()
                
                Exit-Bailout
            }
        } catch [System.Net.HttpListenerException] {
            Write-Log -LogMsg "[!] HTTP Server has hard failed" -LogFile $global:WebLogFile
        }
    }
}


#
# Function : Stop-Webserver
# Shutdown webserver instance
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
# Exit normal
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
# Exit on error
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
# Load webserver plugins
#
Function DynamicLoad-WebPlugins {
    Write-Log -LogMsg "" -LogFile $global:WebLogFile
    Write-Log -LogMsg "Preparing plugins..." -LogFile $global:WebLogFile

    # set Webserver plugin Path
    If (-not ($env:PSModulePath.Contains($global:WebPluginsPath))) {
        #$env:PSModulePath += ";" + $global:WebPluginsPath

        $pathPSModulesTemp = [Environment]::GetEnvironmentVariable("PSModulePath")
        $pathPSModulesTemp += ";" + $global:WebPluginsPath
        [Environment]::SetEnvironmentVariable("PSModulePath", $pathPSModulesTemp)
    }

    # dynamic load webserver plugins
    [system.Array]$pluginsList = @(Get-Module -ListAvailable)

    ForEach($plugin in $pluginsList) {
        If ($plugin.ModuleBase.Contains($global:WebPluginsPath)) {
            # If not already loaded, do load it!
            If (-not (Get-Module -Name $($plugin.Name))) {
                Write-Log -LogMsg "[!] Loading plugin : $($plugin.Name)" -LogFile $global:WebLogFile
                Import-Module -Name $($plugin.Name) -Scope Local -DisableNameChecking
            } Else {
                Write-Log -LogMsg "[i] Plugin already present : $($plugin.Name) (some plugins have a dependency and are auto loaded)" -LogFile $global:WebLogFile
            }
        }
    }

    Write-Log -LogMsg "" -LogFile $global:WebLogFile
}


#
# Function : DynamicUnload-WebPlugins
# Unload webserver plugins
#
Function DynamicUnload-WebPlugins {
    Write-Log -LogMsg "" -LogFile $global:WebLogFile
    Write-Log -LogMsg "Unloading plugins..." -LogFile $global:WebLogFile

    # dynamic unload webserver plugins
    [system.Array]$pluginsListLoaded = @(Get-Module)

    ForEach($plugin in $pluginsListLoaded) {
        If ($plugin.ModuleBase.Contains($global:WebPluginsPath)) {
            Write-Log -LogMsg "[!] Unloading plugin : $($plugin.Name)" -LogFile $global:WebLogFile
            Remove-Module -Name $($plugin.Name) -Force
        }
    }

    Write-Log -LogMsg "" -LogFile $global:WebLogFile
}


#
# Function : Start-LocalLogging
# Start Powershell transscript logging
#
Function Start-LocalLogging
{
    # only start transscript logging of the flag DebugTransscriptLogging is set
    If ($global:DebugTransscriptLogging) {
        # create logs path if not exists
        If (-Not (Test-Path -Path $global:WebLogsPath)) {
            New-Item -Name $global:WebLogsPath -ItemType Directory
        }

        # try enable logging output
        If (Test-Path -Path $global:WebLogsPath) {
            Start-Transcript -OutputDirectory $global:WebLogsPath | Out-Null
        }
    }
}


#
# Function : Stop-LocalLogging
# Stop Powershell transscript logging
#
Function Stop-LocalLogging
{
    # only stop transscript logging of the flag DebugTransscriptLogging is set
    If ($global:DebugTransscriptLogging) {
        If (Test-Path -Path $global:WebLogsPath) {
            Stop-Transcript
        }
    }
}


#
# Function : Write-Log
# Web server logging (stdout)
#
Function Write-Log
{
    Param (
        [Parameter( Mandatory = $false )]
        [string]$LogMsg,
        [Parameter( Mandatory = $True )]
        [string]$LogFile
    )
    	    
    $LogMsgStamped = "[$([environment]::GetEnvironmentVariable("COMPUTERNAME").ToLowerInvariant())_$($global:port)] $((Get-Date).ToString("[dd/MM/yyyy HH:mm:ss]")) $LogMsg"
    If ($global:DebugVerbose) {
        Write-Host $LogMsgStamped
    }

    Add-content $LogFile -value $LogMsgStamped -Force
    #$LogMsgStamped >> $LogFile
}


#
# Function : Send-WebByteResponse
# Send Client Response as byte array
#
Function Send-WebByteResponse {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [byte[]]$ByteStream
    )

    # output stream (html code in a bytes stream), if not empty
   If ( ($Context) -and ($ByteStream) ) {
        $context.Response.ContentLength64 = $ByteStream.Length
        $context.Response.OutputStream.Write($ByteStream, 0, $ByteStream.Length) 
        $context.Response.OutputStream.Close()
    }
}


#
# Function : Send-WebHtmlResponse
# Send Client Response as html code
#
Function Send-WebHtmlResponse {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [string]$HtmlStream
    )

    # output html string stream, if not empty
    # convert to byte stream first.
    If ( ($Context) -and ($HtmlStream) ) {
        $Context.Response.Headers.Add("Content-Type","text/html")
        [byte[]]$someBuffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlStream)
        $context.Response.ContentLength64 = $someBuffer.Length
        $context.Response.OutputStream.Write($someBuffer, 0, $someBuffer.Length) 
        $context.Response.OutputStream.Close()
    }
}


#
# Function : Send-WebResponseCode
# Send Client Response code
#
Function Send-WebResponseCode {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [System.Net.HttpStatusCode]$ResponseCode,
        [Parameter( Mandatory = $False )]
        [string]$ResponseDescription
    )        
    
    # send a response code
    If ( ($Context) -and ($ResponseCode) ) {
        Write-Log -LogMsg "[!] Send response code $($ResponseCode)" -LogFile $global:WebLogFile
        $context.Response.StatusCode = [int32]$ResponseCode
        If ($ResponseDescription) {
            $context.Response.StatusDescription = $ResponseDescription
        }
        $context.Response.Close()
    }
}


#
# Function : Send-WebResponseCode404
# Shortcut function, send Client Response code 404 (Page not found)
#
Function Send-WebResponseCode404 {
    Send-WebResponseCode -Context $context -ResponseCode $([System.Net.HttpStatusCode]::NotFound) -ResponseDescription "Page not found"
}


#
# Function : Send-WebResponseCode501
# Shortcut function, send Client Response code 501 (Not Implemented)
#
Function Send-WebResponseCode501 {
    Send-WebResponseCode -Context $context -ResponseCode $([System.Net.HttpStatusCode]::NotImplemented) -ResponseDescription "Server Not Implemented"
}
#endregion


#region Interpreter Function
#
# Function : Exec-PwshWebDecoder
# HTML Inline interpreter or decoder.
# Executs all lines between <?pwsh and pwsh> tags server side.
#
Function Exec-PwshWebDecoder {
    Param (
        [Parameter( Mandatory = $True )]
        [byte[]]$DataStream
    )

    If ($DataStream) {
        # decode the stream to UTF-8
        [string]$decoderBody = [System.Text.Encoding]::UTF8.GetString($DataStream);
        
        [string]$decodedHTMLLines = [string]::Empty

        # check if we have somewhere in the body the word "pwsh"
        If ($decoderBody.ToLowerInvariant().Contains("?pwsh")) {
            # we always need to have equal pwsh statement, otherwise the decoder will hang forever
            If ($([regex]::Matches($decoderBody, "pwsh" ).Count % 2) -eq 0) {
                # split lines in string
                $decoderBodyArray = @($decoderBody.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries))

                # create code block
                [string]$decoderPwshStatements = [string]::Empty
                
                [bool]$decodingInProgress = $false

                # decoder filters HTML from pwsh code statements
                ForEach($decoderLine In $decoderBodyArray) {
                    [string]$decoderLineTrim = $decoderLine.Trim()

                    # execute pwsh block and finish decoding
                    If ($decoderLineTrim.ToLowerInvariant().Contains("pwsh>")) {
                        If (-not ([string]::IsNullOrEmpty($decoderPwshStatements))) {
                            Write-Log -LogMsg "---- EXECUTE PWSH ----" -LogFile $global:WebLogFile
                            $decoderScriptBlock = [Scriptblock]::Create($decoderPwshStatements)
                            [string]$pwshCodeResult = Invoke-Command -ScriptBlock $decoderScriptBlock
                            $decodedHTMLLines += $($pwshCodeResult) + [Environment]::NewLine                            
                            Write-Log -LogMsg "---- EXECUTE PWSH ----" -LogFile $global:WebLogFile
                            Write-Log -LogMsg "" -LogFile $global:WebLogFile
                        }

                        $decoderScriptBlock = $null
                        $decoderPwshStatements = [string]::Empty
                        $decodingInProgress = $false

                        Continue
                    }

                    # start a new pwsh block
                    If($decoderLineTrim.ToLowerInvariant().Contains("<?pwsh")) {
                        # the line can only start with "<?pwsh", and no other statements may be written on the line
                        $decoderStartVerify = @($decoderLineTrim.Split(" "))

                        If ($decoderStartVerify.Count -eq 1) {
                            $decodingInProgress = $true
                        } Else {
                            Write-Log -LogMsg "---- BAD PWSH ----" -LogFile $global:WebLogFile
                            Write-Log -LogMsg "Check your code : found a bad statement." -LogFile $global:WebLogFile
                            Write-Log -LogMsg "---- BAD PWSH ----" -LogFile $global:WebLogFile
                        }
            
                        Continue
                    }

                    # add new pwsh statement for executioner or filter HTML lines
                    If ($decodingInProgress) {
                        # uncomment for debugging
                        #Write-Log -LogMsg "DEBUG decoder $([char](34))$($decoderLineTrim)$([char](34))"
                        
                        # skip comments, otherwise add to queue for scriptblock
                        If ( ($decoderLineTrim -notlike "<!--*") -and ($decoderLineTrim -notlike ";*") -and ($decoderLineTrim -notlike "#*") -and ($decoderLineTrim -notlike "//*")) {
                            $decoderPwshStatements += $decoderLineTrim + ";"
                        }
                    } else {
                        $decodedHTMLLines += $decoderLine + [Environment]::NewLine
                    }
                }

                Write-Log -LogMsg "" -LogFile $global:WebLogFile
                
            } Else {
                # Decoder Failure! (uneven pwsh statements!)
                $decodedHTMLLines = "<!DOCTYPE html>$([Environment]::NewLine)<html>$([Environment]::NewLine)<title>Error in code</title>$([Environment]::NewLine)<body>$([Environment]::NewLine)Missing begin or end pwsh tag.$([Environment]::NewLine)</body>$([Environment]::NewLine)</html>"
            }        
        } Else {
            # output Plain HTML code (no pwsh detected)
            $decodedHTMLLines = $decoderBody
        }
    }


    Return $decodedHTMLLines
}
#endregion





#region Main function
#
# Function : Main
# C-Style main function
#
Function Main {
    Param (
        [System.Array]$Arguments
    )

    # clear screen if needed
    Clear-Host

    # enable transscript logging
    Start-LocalLogging  

    # extract custom port if requested
    If ($Arguments) {
        for($i = 0; $i -lt $Arguments.Length; $i++) {
            # default, a pwsh Switch statement on a String is always case insensitive
            Switch ($Arguments[$i]) {
                "-port" {                
                    If (($i +1) -le $Arguments.Length) {
                        $global:Port = $Arguments[$i +1]
                        $global:WebLogFile = "$($global:WebLogsPath)\$([environment]::GetEnvironmentVariable("COMPUTERNAME").ToLowerInvariant())_$($global:port).log"
                    }
                }
            }
        }
    }

    # print startup title
    Print-Title

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
            Write-Log -LogMsg "" -LogFile $global:WebLogFile
            Write-Log -LogMsg "** [$($requestTimeStamp)] Request : $($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -LogFile $global:WebLogFile
            Write-Log -LogMsg "   -> Page : $($context.Request.Url.AbsolutePath)" -LogFile $global:WebLogFile
            Write-Log -LogMsg "" -LogFile $global:WebLogFile

            # extra verbose for troubleshooting or debugging
            If ($global:DebugExtraVerbose) {
                Write-Log -LogMsg "-- VERBOSE --" -LogFile $global:WebLogFile
                Write-Log -LogMsg "AbsUri      : $($context.Request.Url.AbsoluteUri)" -LogFile $global:WebLogFile
                Write-Log -LogMsg "RawUrl Path : $($context.Request.RawUrl)" -LogFile $global:WebLogFile
                Write-Log -LogMsg "Abs Path    : $($context.Request.Url.AbsolutePath)" -LogFile $global:WebLogFile
                Write-Log -LogMsg "Local Path  : $($context.Request.Url.LocalPath)" -LogFile $global:WebLogFile
                Write-Log -LogMsg "Referral : $($context.Request.UrlReferrer)" -LogFile $global:WebLogFile
                Write-Log -LogMsg "-- VERBOSE --" -LogFile $global:WebLogFile
            }

            # kill webserver
            # http://127.0.0.1/kill'
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/kill') {
                Write-Log -LogMsg "[!] HTTP Server going down!" -LogFile $global:WebLogFile
                $context.Response.StatusCode = [int32][System.Net.HttpStatusCode]::GatewayTimeout
                $context.Response.StatusDescription = "Gateway timeout"
                $context.Response.Close()

                Start-Sleep -Seconds 1

                Exit-Gracefully
            }

            # webserver ping
            # http://127.0.0.1/ping'
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/ping') {
                Write-Log -LogMsg "[!] Webserver Ping, sending pong" -LogFile $global:WebLogFile
                [string]$pingResponse = "<html><head><title>ping-pong</title><body>Received Ping.<br />Returned Pong!</body></html>"

                #resposed to the request
                Send-WebHtmlResponse -Context $Context -HtmlStream $pingResponse
                Continue          
            }
                        

            # webserver cookie
            # http://127.0.0.1/cookie'
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/cookie') {
                Write-Log -LogMsg "[!] Webserver cookie" -LogFile $global:WebLogFile
                [string]$cookieResponse = "<html><head><title>cookie</title><body>Cookies!</body></html>"

                # ---- read cookie(s)
                [System.Net.Cookie]$getCookie = Get-WebCookie -Context $context -CookieSearchID "ID"

                If ($getCookie) {
                    Write-Log -LogMsg "Found cookie : $($getCookie.Name) = $($getCookie.Value)" -LogFile $global:WebLogFile
                } Else {
                    Write-Log -LogMsg "No cookie found with name $([char](34))ID$([char](34))" -LogFile $global:WebLogFile
                }
                # ---- read cookie(s)

                # ---- write a cookie
                If ($getCookie) {
                    # if exists, clear the existing cookie
                    Clear-WebCookie -Context $context -CookieID "ID"
                } Else {
                    # if not exists, create a cookie
                    Set-WebCookie -Context $context -CookieID "ID" -CookieValue "$([Environment]::GetEnvironmentVariable("USERNAME"))"
                }
                # ---- write a cookie

                #respose to the request
                Send-WebHtmlResponse -Context $Context -HtmlStream $cookieResponse                
                Continue
            }

            
            # forms backend response (from Plugin Web.Postback)
            # http://127.0.0.1/backend/someapppost'
            If ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/backend/someapppost') {
                Invoke-ProcessPostBack -Context $context
                Continue
            }   
            
            # forms backend response (from Plugin Web.Logon)
            # http://127.0.0.1/backend/logon'
            If ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/backend/logon') {
                Validate-Logon -Context $context
                Continue
            } 

            # forms backend response (from Plugin Web.Logon)
            # http://127.0.0.1/backend/logon'
            If ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/backend/logonoff') {
                Remove-Logon -Context $context
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
                        Start-WebRedirect -Context $context -RelativeUrl $redirectUrl -CloseResponse
                        Continue
                    }
                }


                # build local path for serving.
                # Replace forward slash with back slash on Windows. On Linux it will stay the same.
                [string]$pagetoload = "$($global:ContentFolder)$($requestedFilename.Replace("/", [IO.Path]::DirectorySeparatorChar))"
                
                If (-not([string]::IsNullOrEmpty($pagetoload)) -and ($pagetoload.Contains('.'))) {
                    Write-Log -LogMsg "requested Filename : $($requestedFilename)" -LogFile $global:WebLogFile
                    Write-Log -LogMsg "Page to load : $($pagetoload)" -LogFile $global:WebLogFile

                    If (Test-Path -Path $pagetoload) {
                        #[string]$somefile = Get-Content -Path $pagetoload -Raw
                        #$buffer = [System.Text.Encoding]::UTF8.GetBytes($somefile)

                        [byte[]]$streamBuffer = [System.IO.File]::ReadAllBytes($pagetoload)

                        [bool]$bNeedInterpreter = $false

                        Switch -wildcard ($requestedFilename.ToLowerInvariant()) {
                            "*.htm?" { 
                                $context.Response.Headers.Add("Content-Type","text/html")
                                $bNeedInterpreter = $true
                            }
                            #"*.html" { $context.Response.Headers.Add("Content-Type","text/html") }                         
                            "*.css" { $context.Response.Headers.Add("Content-Type","text/css") }
                            "*.csv" { $context.Response.Headers.Add("Content-Type","text/csv") }
                            "*.txt" { $context.Response.Headers.Add("Content-Type","text/plain") }
                            "*.xml" { $context.Response.Headers.Add("Content-Type","text/xml") }
                            "*.js" { $context.Response.Headers.Add("Content-Type","text/javascript") }
                            "*.ico" { $context.Response.Headers.Add("Content-Type","image/vnd.microsoft.icon") }
                            #"*.jpg" { $context.Response.Headers.Add("Content-Type","image/jpeg") }
                            "*.jp?g" { $context.Response.Headers.Add("Content-Type","image/jpeg") }
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
            
                        # our HTML inline interpreter
                        If ($bNeedInterpreter) {                                
                            [string]$strippedHTML = Exec-PwshWebDecoder -DataStream $streamBuffer
                            
                            # overwrite buffer if needed with stripped out pwsh blocks, keeping only plain html code
                            If (-not ([string]::IsNullOrEmpty($strippedHTML))) {
                                $streamBuffer = [System.Text.Encoding]::UTF8.GetBytes($strippedHTML)
                            }
                        }
                        
                        # send our streamBuffer
                        Send-WebByteResponse -Context $context -ByteStream $streamBuffer
                    } Else {
                        # woops, 404    
                        Send-WebResponseCode404
                    }
                }

                Continue
            }


            Write-Log -LogMsg "" -LogFile $global:WebLogFile

            # Do not stop debugging in ISE or Powershell with VSCode
            # better redirect to http://localhost:<webserver_port>/kill" for clean shutdown

        }        
    } else {
        Write-Log -LogMsg "[!] Http server failed!?" -LogFile $global:WebLogFile
    }

    # Exit Gracefully
    Exit-Gracefully
}
#endregion



# -------------------------------------------


# Call Main C-style function
Main -Arguments $args
