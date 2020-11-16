
#
# Pieter De Ridder
# Webserver very basic plugin to emulate logon form
#
# Created : 05/11/2020
# Updated : 16/11/2020
#
# Notice: This module has RequiredModules set in Web.Logon.psd1.
# This module has a requirement for Web.Redirect and Web.Cookies.
#

$CommandsToExport = @()

#
# Function : Validate-Logon
#
Function Validate-Logon {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [String]$LogonCookieName,
        [Parameter( Mandatory = $True )]
        [String]$SuccessURL,
        [Parameter( Mandatory = $True )]
        [String]$FailureURL
    )

    If (($global:http) -and ($Context)) {
       # search for a cookie named "logon"
       [System.Net.Cookie]$logonCookie = Get-WebCookie -Context $context -CookieSearchID $LogonCookieName

       # check if cookie is set or not
       If ($logonCookie) {
            #Set-WebCookie -Context $Context -CookieID $logonCookie.Name -CookieValue $logonCookie.Value
            Start-WebRedirect -Context $context -RelativeUrl $SuccessURL   # "/logon/success.html"
       } Else {
            # decode the form post
            $FormContent = [System.IO.StreamReader]::new($Context.Request.InputStream).ReadToEnd()

            # get postback data from URL
            $data = @{}
            $FormContent.split('&') | %{
                $part = $_.split('=')
                $data.add($part[0], $part[1].Replace("+", " "))
            }

            $usernameForm = $data.item('username')
            $passwordForm = $data.item('password')

            # this is not a real logon form check, just to emulate something
            # values my NOT be empty
            If ((-not ([string]::IsNullOrEmpty($usernameForm))) -or (-not ([string]::IsNullOrEmpty($passwordForm)))) {
                # provided password must check local username that logged on to OS
                If ($passwordForm.ToLowerInvariant().Equals([environment]::GetEnvironmentVariable("USERNAME").ToLowerInvariant())) {
                    Set-WebCookie -Context $Context -CookieID $LogonCookieName -CookieValue "$($usernameForm)"
                    Start-WebRedirect -Context $Context -RelativeUrl $SuccessURL -CloseResponse   # "/logon/success.html"
                } Else {
                    Start-WebRedirect -Context $Context -RelativeUrl $FailureURL -CloseResponse   # "/logon/failed.html"
                    
                    #[string]$html = "<html><head><title>failed</title><h1>A Powershell Webserver</h1><p>Logon failed</p></body></html>"
                    #Send-WebHtmlResponse -Context $Context -HtmlStream $html
                }
            } Else {
                Start-WebRedirect -Context $Context -RelativeUrl $FailureURL -CloseResponse  # "/logon/failed.html"
                
                #[string]$html = "<html><head><title>failed</title><h1>A Powershell Webserver</h1><p>Logon failed</p></body></html>"
                #Send-WebHtmlResponse -Context $Context -HtmlStream $html
            }
       }
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Validate-Logon"


#
# Function : Approve-LogonCheck
#
Function Approve-LogonCheck {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [String]$LogonCookieName,
        [Parameter( Mandatory = $True )]
        [String]$SuccessURL
    )

    If (($global:http) -and ($Context)) {
       [System.Net.Cookie]$logonCookie = Get-WebCookie -Context $Context -CookieSearchID $LogonCookieName

       If ($logonCookie) {
            Write-Log -LogMsg " -> LogonCheck cookie $($LogonCookieName) is set" -LogFile $global:WebLogFile
            Start-WebRedirect -Context $Context -RelativeUrl $SuccessURL   # "/logon/success.html"
       } Else {
            Write-Log -LogMsg " -> LogonCheck cookie $($LogonCookieName) is not set" -LogFile $global:WebLogFile
       }
    } Else {
       # woops, 501
       Send-WebResponseCode501
    }
}
$CommandsToExport += "Approve-LogonCheck"

#
# Function : Approve-SuccessCheck
#
Function Approve-SuccessCheck {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [String]$LogonCookieName,
        [Parameter( Mandatory = $True )]
        [String]$LandingURL
    )

    If (($global:http) -and ($Context)) {
       [System.Net.Cookie]$logonCookie = Get-WebCookie -Context $Context -CookieSearchID $LogonCookieName

       If (-not ($logonCookie)) {
            Write-Log -LogMsg " -> SuccessCheck cookie $($LogonCookieName) is not set" -LogFile $global:WebLogFile
            Start-WebRedirect -Context $Context -RelativeUrl $LandingURL   # "/logon/logon.html"
       } Else {
            Write-Log -LogMsg " -> SuccessCheck cookie $($LogonCookieName) is set" -LogFile $global:WebLogFile
       }
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Approve-SuccessCheck"


#
# Function : Remove-Logon
#
Function Remove-Logon {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [String]$LogonCookieName,
        [Parameter( Mandatory = $True )]
        [String]$LandingURL
    )

    If (($global:http) -and ($Context)) {
       [System.Net.Cookie]$logonCookie = Get-WebCookie -Context $Context -CookieSearchID $LogonCookieName

       If ($logonCookie) {
           Clear-WebCookie -Context $Context -CookieID $LogonCookieName
           Start-WebRedirect -Context $Context -RelativeUrl $LandingURL   # "/logon"
       }
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Remove-Logon"

Export-ModuleMember -Function $CommandsToExport
