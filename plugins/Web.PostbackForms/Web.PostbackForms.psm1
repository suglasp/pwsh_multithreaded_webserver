
#
# Pieter De ridder
# My Webserver plugin
#
# Created : 02/11/2020
# Updated : 02/11/2020
#

$CommandsToExport = @()

Function Invoke-ProcessPostBack {
    Param (
        [System.Net.HttpListenerContext]$context
    )

    If (($global:http) -and ($context)) {
        
        # decode the form post
        # html form members need 'name' attributes as in the example!
        $FormContent = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

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
        $context.Response.Headers.Add("Content-Type","text/html")
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.OutputStream.Close()
    }
}
$CommandsToExport += "Invoke-ProcessPostBack"


Export-ModuleMember -Function $CommandsToExport
