
#
# Pieter De Ridder
# Webserver Cookies Plugin
#
# Created : 04/11/2020
# Updated : 08/01/2021
#

$CommandsToExport = @()


#
# Function : Get-WebCookie
#
Function Get-WebCookie {
    Param (
		[Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
		[Parameter( Mandatory = $True )]
		[string]$CookieSearchID
    )

	Write-Log -LogMsg " -> Get cookie $([char](34))$($CookieSearchID)$([char](34))" -LogFile $global:WebLogFile

    If (($global:http) -and ($Context)) {	
		[System.Net.CookieCollection]$cookiesList = $context.Request.Cookies

        # find cookie
		If ( ($cookiesList) -and (-not [string]::IsNullOrEmpty($CookieSearchID)) ) {
			Write-Log -LogMsg "     |-> Enum cookies list" -LogFile $global:WebLogFile
            ForEach($getCookie In $cookiesList) {
				If ($getCookie.Name.ToLowerInvariant().Equals($CookieSearchID.ToLowerInvariant())) {
                    Write-Log -LogMsg "     |-> Found in cache" -LogFile $global:WebLogFile
                    Return $getCookie
				}
			}
		}
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
	
    Return $null
}
$CommandsToExport += "Get-WebCookie"


#
# Function : Set-WebCookie
#
Function Set-WebCookie {
    Param (
		[Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
		[Parameter( Mandatory = $True )]
		[string]$CookieID,
		[Parameter( Mandatory = $True )]
		[string]$CookieValue,
        [Parameter( Mandatory = $False )]
		[string]$CookiePath = "/",
        [Parameter( Mandatory = $False )]
		[System.DateTime]$CookieExpires = $((Get-Date).AddDays(1))
    )

	Write-Log -LogMsg " -> Set cookie" -LogFile $global:WebLogFile

    If (($global:http) -and ($Context) -and (-not [string]::IsNullOrEmpty($CookieID))) {
        [System.Net.Cookie]$setCookie = [System.Net.Cookie]::new()

		# set cookie
		$setCookie.Name = "$($CookieID)"
		$setCookie.Value = "$($CookieValue)"
		$setCookie.Expires = $CookieExpires
		$setCookie.Secure = $true
        $setCookie.Expired = $false
        $setCookie.Path = $CookiePath
		$Context.Response.SetCookie($setCookie)
		#$context.Response.AddHeader("Set-Cookie", "$($setCookie.Name)=$($setCookie.Value)")
		#$context.Response.AppendHeader("Set-Cookie", "name2=value2")
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Set-WebCookie"


#
# Function : Clear-WebCookie
#
Function Clear-WebCookie {
    Param (
		[Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
		[Parameter( Mandatory = $True )]
		[string]$CookieID
    )

	Write-Log -LogMsg " -> Want to clean a cookie" -LogFile $global:WebLogFile

    If (($global:http) -and ($Context)) {	
        [System.Net.CookieCollection]$cookiesList = $context.Request.Cookies
        
		If ( ($cookiesList) -and (-not [string]::IsNullOrEmpty($CookieID)) ) {
            Write-Log -LogMsg " -> Want to clean a cookie" -LogFile $global:WebLogFile

			ForEach($getCookie In $cookiesList) {
				If ($getCookie.Name.ToLowerInvariant().Equals($CookieID.ToLowerInvariant())) {

                    # one way to delete cookie, is expire it and rewrite it
                    [System.Net.Cookie]$updateCookie = $getCookie
                    $updateCookie.Value = [string]::Empty
                    $updateCookie.Expires = (Get-Date).AddSeconds(-30) # expire big time
                    $updateCookie.Expired = $true
                    $Context.Response.SetCookie($updateCookie)

                    # other way is to remove it from the collection
                    #$Context.Response.Cookies.Remove($getCookie)
                    #$Context.Response.Cookies.Remove($cookiesList.Item($getCookie.Name))

                    Write-Log -LogMsg " -> Cleaned cookie $($getCookie.Name)" -LogFile $global:WebLogFile
                    Break
				}
			}
		}
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Clear-WebCookie"


#
# Function : Clear-WebCookieAll
#
Function Clear-WebCookieAll {
    Param (
		[Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context
    )

    Write-Log -LogMsg " -> Want to clean ALL cookies" -LogFile $global:WebLogFile

    If (($global:http) -and ($Context)) {        
        [System.Net.CookieCollection]$cookiesList = $context.Request.Cookies
        
        If ( ($cookiesList) -and ($cookiesList.Count -gt 0) ) {
            $Context.Response.Cookies.Clear()
        }

        Write-Log -LogMsg " -> Cleaned ALL cookies" -LogFile $global:WebLogFile
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Clear-WebCookieAll"



Export-ModuleMember -Function $CommandsToExport
