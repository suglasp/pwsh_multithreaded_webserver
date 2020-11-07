
#
# Pieter De Ridder
# Webserver very basic plugin to emulate logon form
#
# Created : 05/11/2020
# Updated : 07/11/2020
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
        [System.Net.HttpListenerContext]$Context
    )

    If (($global:http) -and ($Context)) {
       # search for a cookie named "logon"
       [System.Net.Cookie]$logonCookie = Get-WebCookie -Context $context -CookieSearchID "pwshlogonid"

       # check if cookie is set or not
       If ($logonCookie) {
            #Set-WebCookie -Context $Context -CookieID $logonCookie.Name -CookieValue $logonCookie.Value
            Start-WebRedirect -Context $context -RelativeUrl "/logon/success.html"
       } Else {
            # decode the form post
            $FormContent = [System.IO.StreamReader]::new($Context.Request.InputStream).ReadToEnd()

            # get postback data from URL
            $data = @{}
            $FormContent.split('&') | %{
                $part = $_.split('=')
                $data.add($part[0], $part[1].Replace("+", " "))
            }

            $username = $data.item('username')
            $password = $data.item('password')

            # this is not a real logon form check, just to emulate something
            # values my NOT be empty
            If ((-not ([string]::IsNullOrEmpty($username))) -or (-not ([string]::IsNullOrEmpty($password)))) {
                # provided password must check local username that logged on to OS
                If ($password.ToLowerInvariant().Equals([environment]::GetEnvironmentVariable("USERNAME").ToLowerInvariant())) {
                    Set-WebCookie -Context $Context -CookieID "pwshlogonid" -CookieValue "$([Environment]::GetEnvironmentVariable("USERNAME"))"
                    Start-WebRedirect -Context $Context -RelativeUrl "/logon/success.html"
                } Else {
                    Start-WebRedirect -Context $Context -RelativeUrl "/logon/failed.html"
                }
            } Else {
                Start-WebRedirect -Context $Context -RelativeUrl "/logon/failed.html"
            }
       }
    }
}
$CommandsToExport += "Validate-Logon"


#
# Function : Approve-Logon
#
Function Approve-Logon {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context
    )

    If (($global:http) -and ($Context)) {
       [System.Net.Cookie]$logonCookie = Get-WebCookie -Context $Context -CookieSearchID "pwshlogonid"

       If (-not ($logonCookie)) {
           Start-WebRedirect -Context $Context -RelativeUrl "/logon/logon.html"
       }
    }
}
$CommandsToExport += "Approve-Logon"


#
# Function : Remove-Logon
#
Function Remove-Logon {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context
    )

    If (($global:http) -and ($Context)) {
       [System.Net.Cookie]$logonCookie = Get-WebCookie -Context $Context -CookieSearchID "pwshlogonid"

       If ($logonCookie) {
           Clear-WebCookie -Context $Context -CookieID "pwshlogonid"
           Start-WebRedirect -Context $Context -RelativeUrl "/logon"
       }
    }
}
$CommandsToExport += "Remove-Logon"

Export-ModuleMember -Function $CommandsToExport
