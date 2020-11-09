
#
# Pieter De Ridder
# https://www.github.com/suglasp
#
# Macro-Interpreter (or parser/-decoder) to filter Powershell statement inline with html code.
# The result is, it executes statement from within the html code as Powershell.
# The output is html code (to return to browser).
# This code is a test sample, that was later backported to my "Scalable Powershell Webserver" project.
#
# Created : 06/11/2020
# Updated : 09/11/2020
#


#
# Function : Exec-PwshWebDecoder
# HTML Inline macro-interpreter or decoder.
# Executs all lines between <?pwsh and pwsh> tags on server-side.
#
Function Exec-PwshWebDecoder {
    Param (
        [Parameter( Mandatory = $True )]
        [byte[]]$DataStream
    )

    If ($DataStream) {
        # decode the stream to UTF-8
        [string]$decoderBody = [System.Text.Encoding]::UTF8.GetString($DataStream);
        
        [string]$decodedHTMLLines = [string]::Empty

        # check if we have somewhere in the body the word "pwsh"
        If ($decoderBody.ToLowerInvariant().Contains("<?pwsh")) {
            # we always need to have equal pwsh statement, otherwise the decoder will hang forever
            If ($([System.Text.RegularExpressions.Regex]::Matches($decoderBody, "(<[\?]pwsh|pwsh[>])", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count % 2) -eq 0) {
            #If ($([System.Text.RegularExpressions.Regex]::Matches($decoderBody, "pwsh" ).Count % 2) -eq 0) {
                # split lines in string
                $decoderBodyArray = @($decoderBody.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries))

                # create code block
                [string]$decoderPwshStatements = [string]::Empty
                
                [bool]$decodingInProgress = $false

                # decoder filters HTML from pwsh code statements
                ForEach($decoderLine In $decoderBodyArray) {
                    [string]$decoderLineTrim = $decoderLine.Trim()

                    # execute pwsh block and finish decoding
                    # the line can only end with "pwsh>", and no other statements may be written on the line
                    If ($decoderLineTrim.ToLowerInvariant().Contains("pwsh>")) {
                        If (-not ([string]::IsNullOrEmpty($decoderPwshStatements))) {
                            Write-Host "---- EXECUTE PWSH ----" -ForegroundColor Red
                            $decoderScriptBlock = [Scriptblock]::Create($decoderPwshStatements)
                            [string]$pwshCodeResult = Invoke-Command -ScriptBlock $decoderScriptBlock
                            $decodedHTMLLines += $($pwshCodeResult) + [Environment]::NewLine                            
                            Write-Host "---- EXECUTE PWSH ----" -ForegroundColor Red
                            Write-Host ""
                        }

                        $decoderScriptBlock = $null
                        $decoderPwshStatements = [string]::Empty
                        $decodingInProgress = $false

                        Continue
                    }

                    # start a new pwsh block
                    If($decoderLineTrim.ToLowerInvariant().Contains("<?pwsh")) {
                        # the line can only start with "<?pwsh", and no other statements may be written on the line
                        $decoderStartVerify = @($decoderLineTrim.Split(" "))

                        If ($decoderStartVerify.Count -eq 1) {
                            $decodingInProgress = $true
                        } Else {
                            Write-Host "---- BAD PWSH ----" -ForegroundColor Red
                            Write-Host "Check your code : found a bad statement."
                            Write-Host "---- BAD PWSH ----" -ForegroundColor Red
                        }
            
                        Continue
                    }

                    # add new pwsh statement for executioner or filter HTML lines
                    If ($decodingInProgress) {
                        # uncomment for debugging
                        #Write-Host "DEBUG decoder $([char](34))$($decoderLineTrim)$([char](34))"
                        
                        # skip comments, otherwise add to queue for scriptblock
                        If ( ($decoderLineTrim -notlike "<!--*") -and ($decoderLineTrim -notlike ";*") -and ($decoderLineTrim -notlike "#*") -and ($decoderLineTrim -notlike "//*")) {
                            $decoderPwshStatements += $decoderLineTrim + ";"
                        }
                    } else {
                        $decodedHTMLLines += $decoderLine + [Environment]::NewLine
                    }
                }

                Write-Host ""
                
            } Else {
                Write-Host "---- Decoder Failure! (uneven pwsh statements!) ----" -ForegroundColor Black -BackgroundColor Red
            }      

        
        } Else {
            Write-Host "---- Plain HTML code (no pwsh detected) ----" -ForegroundColor Green
            $decoderBody
            Write-Host "---- Plain HTML code (no pwsh detected) ----" -ForegroundColor Green
        }
    }


    Return $decodedHTMLLines
}





# -------------------------- MAIN PROGRAM EXECUTION -----------------

[string]$global:WorkFolder = $PSScriptRoot

#[string]$pagetoload = $null
#[string]$pagetoload = "$($global:WorkFolder)\decodertest.html"
#[string]$pagetoload = "$($global:WorkFolder)\decodertest_returnvalue.html"
[string]$pagetoload = "$($global:WorkFolder)\decodertest_upper_lower.html"
#[string]$pagetoload = "$($global:WorkFolder)\decodertestbad1.html"
#[string]$pagetoload = "$($global:WorkFolder)\decodertestbad2.html"
#[string]$pagetoload = "$($global:WorkFolder)\decodertestnocode.html"

Write-Host ""
Write-Host "parse file : $($pagetoload)" -ForegroundColor Cyan
Write-Host ""

If (Test-Path -Path "$($pagetoload)") {
    # read file as stream
    $buffer = [System.IO.File]::ReadAllBytes($pagetoload)

    [string]$HTML = Exec-PwshWebDecoder -DataStream $buffer


    Write-Host "---- Result HTML code ----" -ForegroundColor Yellow
    $HTML
    Write-Host "---- Result HTML code ----" -ForegroundColor Yellow
} Else {
    Write-Warning "failure loading file!"
}

Exit 0
