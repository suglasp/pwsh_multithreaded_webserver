## Powershell "Multithreaded" Utility Webserver.

( Note : Improved version of [github gist reference](https://gist.github.com/19WAS85/5424431) )

**Why?** 
I needed a webserver to host a tools/utility webpage as a sysadmin.
The utility page needed to be flexible and be able to interact with low level components.
Go lang or Rust would fit to, but takes more time to build and also in Powershell
many of these low level components are present.
In one day, I put this together and make it so, so that more then one user can interact with
the webserver at the same time.

**How it works** 
- pwsh_webserver_bootstrap.ps1       : is used to start, stop, restart, ... all running instances.
                                     instances start at port 8080 and ramp up by how much is provided.
- pwsh_webserver_instance.ps1        : core script, this is a single instance of a webserver.
- pwsh_webserver_server_raw_stop.ps1 : quick script to stop single instance (script used for development)
- pwsh_webserver_create_module.ps1   : quick script to create a plugin for the webserver

**Sub-Folders** 
- ./content : all content goes here (html, htm, css, gif, jpg, png, ico, zip, ...)
- ./loadbalancer : nginx binary (executable) and all subfolders need to be placed here
- ./logs : log files of the webserver instances (pwsh_webserver_instance.ps1)
- ./plugins : plugins go here (basically, they are Powershell modules)

**Configuration**
1) edit config file ./loadbalancer/config/nginx.conf:
   config the loadbalancer, for example add more web instances, enable ip hasing, enable ssl)
2) subfolder ./content :
   place your website content here
3) Edit file pwsh_webserver_bootstrap.ps1:
   edit line $global:WebCount, to set the number of instances you want.
   edit line $global:WebStartPort, to define the start port of the first instance.
4) Edit file pwsh_webserver_instance.ps1:
   edit line $global:PublishLocalhost. If $true (= localhost only), if $false (= public)

Starting webserver instances from Powershell (*):
> .\pwsh_webserver_bootstrap.ps1 -start

Stopping running webserver instances from Powershell (*):
> .\pwsh_webserver_bootstrap.ps1 -start

Restarting webserver instances from Powershell (*):
> .\pwsh_webserver_bootstrap.ps1 -reload

(*) *Running a webserver on ports below 1024 (wel known ports), you must run Powershell (or pwsh) in Elevated mode (Windows) or Root (Linux) to listen on for example port tcp/80 and tcp/443.
Otherwise, you can just run it normally if it's for testing and running on port tcp/8080 or any of tcp/[1025-65535].*

Pieter De Ridder (Suglasp)
