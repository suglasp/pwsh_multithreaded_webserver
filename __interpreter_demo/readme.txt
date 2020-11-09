
Tryout for a basic server-side macro-interpreter to execute Powershell code inline with a html page.

I've introduced a few new html tags (a bit like php), in a html page, if you write:

<?pwsh
  <!-- write here some pwsh code -->
  Write-Host "some inline code, yey!"
pwsh>

This will be executed.
All html lines will be send to the client (that is the intention).
All Powershell statements will be executed in the running Powershell "web instance" process.

You can use comments like you want:
; a comment
# a comment
// a comment
<!-- a comment -->


Pieter De Ridder a.k.a. Suglasp
https://www.github.com/suglasp
