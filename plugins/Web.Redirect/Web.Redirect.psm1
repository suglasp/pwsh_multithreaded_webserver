
#
# Pieter De Ridder
# Webserver Redirect Plugin
#
# Created : 05/11/2020
# Updated : 07/11/2020
#

$CommandsToExport = @()

#
# Function : Start-WebRedirect
#
Function Start-WebRedirect {
    Param (
		[Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context,
        [Parameter( Mandatory = $True )]
        [string]$RelativeUrl
    )

    If (($global:http) -and ($Context)) {
        If (-not ([string]::IsNullOrEmpty($RelativeUrl))) {
            # redirect client to other Url
            Write-Log -LogMsg " -> Redirecting client to $($RelativeUrl)." -LogFile $global:WebLogFile
            $context.Response.Redirect($RelativeUrl)
            #$context.Response.Close()
        } Else {
            # woops, 404                
            $context.Response.StatusCode = [int32][System.Net.HttpStatusCode]::NotFound
            $context.Response.StatusDescription = "Page not found"
            $context.Response.Close()
        }
    }

}
$CommandsToExport += "Start-WebRedirect"


Export-ModuleMember -Function $CommandsToExport

