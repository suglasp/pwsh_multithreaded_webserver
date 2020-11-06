
#
# Pieter De Ridder
# Decoder/parser to filter powershell statement out of html code
# The result it executes statement in the html code as powershell.
# The output is html code (to return to browser)
#
# Created : 06/11/2020
# Updated : 06/11/2020
#

#
# Function : Exec-PwshWebDecoder
#
Function Exec-PwshWebDecoder {
    Param (
        [Parameter( Mandatory = $True )]
        [byte[]]$DataStream
    )

    If ($DataStream) {
        # decode the stream to UTF-8
        $decoderBody = [System.Text.Encoding]::UTF8.GetString($DataStream);

        # check if we have somewhere in the body the word "pwsh"
        If ($decoderBody.ToLowerInvariant().Contains("pwsh")) {
            # we always need to have equal pwsh statement, otherwise the decoder will hang forever
            If ($([regex]::Matches($decoderBody, "pwsh" ).Count % 2) -eq 0) {
                # split lines in string
                $decoderBodyArray = $decoderBody.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

                # create code block
                [string]$decoderPwshStatements = [string]::Empty
                [string]$decoderHTMLLines = [string]::Empty
                [bool]$decodingInProgress = $false

                # decoder filters HTML from pwsh code statements
                ForEach($decoderLine In $decoderBodyArray) {
                    # end pwsh block and execute
                    If ($decoderLine.Trim().ToLowerInvariant().Contains("pwsh>")) {
                        If (-not ([string]::IsNullOrEmpty($decoderPwshStatements))) {
                            Write-Host "---- EXECUTE PWSH ----" -ForegroundColor Red
                            $decoderScriptBlock = [Scriptblock]::Create($decoderPwshStatements)
                            Invoke-Command -ScriptBlock $decoderScriptBlock
                            $decoderScriptBlock = $null
                            $decoderPwshStatements = [string]::Empty
                            $decodingInProgress = $false
                            Write-Host "---- EXECUTE PWSH ----" -ForegroundColor Red
                            Write-Host ""
                        }

                        Continue
                    }

                    # start a new pwsh block
                    If($decoderLine.Trim().ToLowerInvariant().Contains("<?pwsh")) {
                        # the line can only start with "<?pwsh", and no other statements may be written on the line
                        $decoderStartVerify = @($decoderLine.Trim().Split(" "))

                        If ($decoderStartVerify.Count -eq 1) {
                            $decodingInProgress = $true
                        } Else {
                            Write-Host "---- BAD PWSH ----" -ForegroundColor Red
                            Write-Host "Check code, found bad statement."
                            Write-Host "---- BAD PWSH ----" -ForegroundColor Red
                        }
            
                        Continue    
                    }

                    # add new pwsh statement for executioner or filter HTML lines
                    If ($decodingInProgress) {
                        $decoderPwshStatements += $decoderLine + ";"
                    } else {
                        $decoderHTMLLines += $decoderLine + [Environment]::NewLine
                    }
                }

                Write-Host ""
                Write-Host "---- Decoded HTML code ----" -ForegroundColor Yellow
                $decoderHTMLLines
                Write-Host "---- Decoded HTML code ----" -ForegroundColor Yellow
            } Else {
                Write-Host "---- Decoder Failure! (uneven pwsh statements!) ----" -ForegroundColor Black -BackgroundColor Red
            }      

        
        } Else {
            Write-Host "---- Plain HTML code (no pwsh detected) ----" -ForegroundColor Green
            $decoderBody
            Write-Host "---- Plain HTML code (no pwsh detected) ----" -ForegroundColor Green
        }
    }    
}




# -------------------------- MAIN PROGRAM EXECUTION -----------------

[string]$global:WorkFolder = $PSScriptRoot

#[string]$pagetoload = $null
#[string]$pagetoload = "$($global:WorkFolder)\decodertest.html"
#[string]$pagetoload = "$($global:WorkFolder)\decodertestbad1.html"
[string]$pagetoload = "$($global:WorkFolder)\decodertestbad2.html"
#[string]$pagetoload = "$($global:WorkFolder)\decodertestnocode.html"

Write-Host ""
Write-Host "parse file : $($pagetoload)" -ForegroundColor Cyan
Write-Host ""

If (Test-Path -Path "$($pagetoload)") {
    # read file as stream
    $buffer = [System.IO.File]::ReadAllBytes($pagetoload)

    Exec-PwshWebDecoder -DataStream $buffer
} Else {
    Write-Warning "failure loading file!"
}

Exit 0
