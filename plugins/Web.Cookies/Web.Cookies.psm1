
#
# Pieter De Ridder
# Webserver Cookies Plugin
#
# Created : 04/11/2020
# Updated : 08/11/2020
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

	Write-Log -LogMsg " -> Get cookie" -LogFile $global:WebLogFile

    If (($global:http) -and ($Context)) {	
		[System.Net.CookieCollection]$cookiesList = $context.Request.Cookies

        # find cookie
		If ($cookiesList) {
			ForEach($getCookie In $cookiesList) {
				If ($getCookie.Name.ToLowerInvariant().Equals($CookieSearchID.ToLowerInvariant())) {
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

    If (($global:http) -and ($Context)) {
        [System.Net.Cookie]$setCookie = [System.Net.Cookie]::new()

		# set cookie
		$setCookie.Name = "$($CookieID)"
		$setCookie.Value = "$($CookieValue)"
		$setCookie.Expires = $CookieExpires
		$setCookie.Secure = $true
        $setCookie.Expired = $false
        $setCookie.Path = $CookiePath
		#$Context.Response.SetCookie($setCookie)
		$context.Response.AddHeader("Set-Cookie", "$($setCookie.Name)=$($setCookie.Value)");
		#$context.Response.AppendHeader("Set-Cookie", "name2=value2");
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

	Write-Log -LogMsg " -> Clean cookie" -LogFile $global:WebLogFile

    If (($global:http) -and ($Context)) {	
		[System.Net.CookieCollection]$cookiesList = $context.Request.Cookies

		[bool]$cookieFound = $false

		If ($cookiesList) {
			ForEach($getCookie in $cookiesList) {
				If ($getCookie.Name.ToLowerInvariant() -eq $CookieID.ToLowerInvariant()) {
					$cookieFound = $true
				}
			}                    
		}
		
		If ($cookieFound) {
			[System.Net.Cookie]$setCookie = [System.Net.Cookie]::new()

			# clear cookie (empty value)
			$setCookie.Name = "$($CookieID)"
			$setCookie.Value = ""
			$setCookie.Expires = (Get-Date).AddMonths(-1) # expire big time
            $setCookie.Expired = $false
			$Context.Response.SetCookie($setCookie)
		}
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Clear-WebCookie"

Export-ModuleMember -Function $CommandsToExport
