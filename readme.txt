
Powershell "Multithreaded" Utility Webserver.

(Note : Improved version of https://gist.github.com/19WAS85/5424431)


Why?
I needed a webserver to host a tools/utility webpage as a sysadmin.
The utility page needed to be flexible and be able to interact with low level components.
Go lang or Rust would fit to, but takes more time to build and also in Powershell
many of there low level components are present.
In one day, i put this together and make it so, so that more then one user can interact with
the webserver at the same time.


How it works:
pwsh_webserver_bootstrap.ps1       : is used to start, stop, restart, ... all running instances.
                                     instances start at port 8080 and ramp up by how much is provided.
pwsh_webserver_instance.ps1        : core script, this is a single instance of a webserver.
pwsh_webserver_server_raw_stop.ps1 : quick script to stop single instance (used for testing of development of pwsh_webserver_instance.ps1)
pwsh_webserver_create_module.ps1   : quick script to create a plugin for the webserver

Folders:
./content : all content goes here (html, htm, css, gif, jpg, png, ico, zip, ...)
./loadbalancer : nginx binary (executable) and all subfolders need to be placed here
./logs : log files of the webserver instances (pwsh_webserver_instance.ps1)
./plugins : plugins go here (basically, they are Powershell modules)

Configuration:
./loadbalancer/config/nginx.conf should be edited (for example add more web instances for load balancing, enable ip hasing, enable ssl)
./content : place your website here
in pwsh_webserver_bootstrap.ps1, edit $global:WebCount to the number of instances you want. Default is 2 instances (listening on port 8080 and 8081)
in pwsh_webserver_instance.ps1, edit $global:PublishLocalhost to $true (localhost only) or $false (public)

Starting webserver:
Run powershell (or pwsh), on Windows it must be Elevated to listen on port 80/443. Otherwise, you can just run it normally.
.\pwsh_webserver_bootstrap.ps1 -start to start the instances.

Stopping running webserver:
Run powershell (or pwsh), on Windows it must be Elevated to listen on port 80/443. Otherwise, you can just run it normally.
.\pwsh_webserver_bootstrap.ps1 -start to stop the instances.

Starting webserver:
Run powershell (or pwsh), on Windows it must be Elevated to listen on port 80/443. Otherwise, you can just run it normally.
.\pwsh_webserver_bootstrap.ps1 -reload to restart the whole stack.

Pieter De Ridder (Suglasp)
