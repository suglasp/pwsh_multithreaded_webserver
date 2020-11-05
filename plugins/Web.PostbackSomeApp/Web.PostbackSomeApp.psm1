
#
# Pieter De Ridder
# Webserver plugin to test Form postback input named as "someapp"
#
# Created : 02/11/2020
# Updated : 05/11/2020
#

$CommandsToExport = @()


#
# Function : Invoke-ProcessPostBack
#
Function Invoke-ProcessPostBack {
    Param (
        [Parameter( Mandatory = $True )]
        [System.Net.HttpListenerContext]$Context
    )

    If (($global:http) -and ($Context)) {
        
        # decode the form post
        $FormContent = [System.IO.StreamReader]::new($Context.Request.InputStream).ReadToEnd()

        Write-Host "Content : $($FormContent)"

        # get postback data from URL
        $data = @{}
        $FormContent.split('&') | %{
            $part = $_.split('=')
            $data.add($part[0], $part[1].Replace("+", " "))
        }

        $username = $data.item('fullname')
        $msg = $data.item('message')

        # the html/data response
        [string]$html = "<h1>A Powershell Webserver</h1><p>Post Successful!</p><p>user: $($username)<br />message: $($msg)</p>" 

        #resposed to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $Context.Response.Headers.Add("Content-Type","text/html")
        $Context.Response.ContentLength64 = $buffer.Length
        $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $Context.Response.OutputStream.Close()
    }
}
$CommandsToExport += "Invoke-ProcessPostBack"


Export-ModuleMember -Function $CommandsToExport
