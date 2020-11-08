
#
# Pieter De Ridder
# Webserver Redirect Plugin
#
# Created : 05/11/2020
# Updated : 08/11/2020
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
        [string]$RelativeUrl,
        [Parameter( Mandatory = $False )]
        [switch]$CloseResponse
    )

    If (($global:http) -and ($Context)) {
        If (-not ([string]::IsNullOrEmpty($RelativeUrl))) {
            # redirect client to other Url
            Write-Log -LogMsg " -> Redirecting client to $($RelativeUrl)." -LogFile $global:WebLogFile
            $context.Response.Redirect($RelativeUrl)

            If ($CloseResponse) {
                # force close response
                $context.Response.Close()
            }
        } Else {
            # woops, 404
            Send-WebResponseCode404
        }
    } Else {
        # woops, 501
        Send-WebResponseCode501
    }

}
$CommandsToExport += "Start-WebRedirect"


Export-ModuleMember -Function $CommandsToExport

