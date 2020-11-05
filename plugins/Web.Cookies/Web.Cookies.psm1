
#
# Pieter De Ridder
# Webserver Cookies Plugin
#
# Created : 04/11/2020
# Updated : 05/11/2020
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

    Write-Host " -> Get cookie"

    [System.Net.Cookie]$foundCookie = $null

    If (($global:http) -and ($Context)) {	
		[System.Net.CookieCollection]$cookiesList = $context.Request.Cookies

		If ($cookiesList) {
			ForEach($getCookie In $cookiesList) {
				If ($getCookie.Name.ToLowerInvariant().Equals($CookieSearchID.ToLowerInvariant())) {
                    Write-Host "    found."
					$foundCookie = $getCookie
				}
			}
		}
    }
	
	Return $foundCookie
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
		[string]$CookieValue
    )

    Write-Host " -> Set cookie"

    If (($global:http) -and ($Context)) {
        [System.Net.Cookie]$setCookie = [System.Net.Cookie]::new()

		# set cookie
		$setCookie.Name = "$($CookieID)"
		$setCookie.Value = "$($CookieValue)"
		#$setCookie.Expires = (Get-Date).AddDays(1)
		$setCookie.Secure = $true
		#$Context.Response.SetCookie($setCookie)
		$context.Response.AddHeader("Set-Cookie", "$($setCookie.Name)=$($setCookie.Value)");
		#$context.Response.AppendHeader("Set-Cookie", "name2=value2");
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

    Write-Host " -> Clean cookie"

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
			$setCookie.Expires = (Get-Date).AddDays(-1)
			$Context.Response.SetCookie($setCookie)
		}
    }
}
$CommandsToExport += "Clear-WebCookie"

Export-ModuleMember -Function $CommandsToExport
