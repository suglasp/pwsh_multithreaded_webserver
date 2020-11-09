
#
# Pieter De Ridder
# Webserver Cookies Plugin
#
# Created : 04/11/2020
# Updated : 09/11/2020
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

    If (($global:http) -and ($Context) -and (-not [string]::IsNullOrEmpty($CookieID))) {
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

	Write-Log -LogMsg " -> Want to clean a cookie" -LogFile $global:WebLogFile

    If (($global:http) -and ($Context)) {	
        [System.Net.CookieCollection]$cookiesList = $context.Request.Cookies

        #[bool]$cookieFound = $false

		If ( ($cookiesList) -and (-not [string]::IsNullOrEmpty($CookieID)) ) {
			ForEach($getCookie in $cookiesList) {
				If ($getCookie.Name.ToLowerInvariant().Equals($CookieID.ToLowerInvariant())) {
                    [System.Net.Cookie]$updateCookie = $getCookie
                    $updateCookie.Value = [string]::Empty
                    $updateCookie.Expires = (Get-Date).AddSeconds(-30) # expire big time
                    $updateCookie.Expired = $true
                    $updateCookie

                    #$cookiesList.Remove($getCookie)
                    #$cookiesList.Remove($cookiesList.Item($getCookie.Name))
                    #$Context.Response.Cookies.Remove($cookiesList.Item($getCookie.Name))
                    #$cookieFound = $true
                    $Context.Response.SetCookie($updateCookie)
                    Write-Log -LogMsg " -> Cleaned cookie $($updateCookie.Name)" -LogFile $global:WebLogFile
                    Break
				}
			}
		}
		
		#If ($cookieFound) {
		#	[System.Net.Cookie]$setCookie = [System.Net.Cookie]::new()
        #
		#	# clear cookie (empty value)
		#	$setCookie.Name = "$($CookieID)"
		#	$setCookie.Value = [string]::Empty
		#	$setCookie.Expires = (Get-Date).AddSeconds(-30) # expire big time
        #   $setCookie.Expired = $true
		#	$Context.Response.SetCookie($setCookie)
        #   Write-Log -LogMsg " -> Cleaned cookie $($setCookie.Name)" -LogFile $global:WebLogFile
		#}
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }
}
$CommandsToExport += "Clear-WebCookie"

Export-ModuleMember -Function $CommandsToExport
