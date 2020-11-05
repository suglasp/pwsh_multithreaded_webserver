## Powershell "Multithreaded" Utility Webserver.

( Note : Improved version of [github gist reference](https://gist.github.com/19WAS85/5424431) )

**Why?** 
I needed a webserver to host a tools/utility webpage as a sysadmin.
The utility page needed to be flexible and be able to interact with low level components.
Go lang or Rust would fit to, but takes more time to build and also in Powershell
many of these low level components are present.
In one day, I put this together and make it so, so that more then one user can interact with
the webserver at the same time.

The part _'multithreaded'_ in the github name, is in fact untrue.
Because we use Nginx as a loadbalancer in 'front' of the Powershell web instances, it "looks" multithreaded.
But the true naming is actually horizontal scalability.

**How it works** 

- pwsh_webserver_bootstrap.ps1       : is used to start, stop, restart, ... all running instances.
                                     instances start at port 8080 and ramp up by how much is provided.
- pwsh_webserver_instance.ps1        : core script, this is a single instance of a webserver.
- pwsh_webserver_server_raw_stop.ps1 : quick script to stop single instance (script used for development)
- pwsh_webserver_create_module.ps1   : quick script to create a plugin for the webserver



The purpose is the bootstrap script launches a number of web instances (Powershell), and one Nginx instance.
Nginx loadbalances all incomming requests over all web instances.
Nginx should be listening to the ouside world, while the web instances should listen on localhost (in case on a single machine).
For performance reasons, one could define routes in the Nginx config for static files (html, js, images, ...).
It is possible by changing a parameter to let the web instances listen "outside".




**Sub-Folders** 
- ./content : all content goes here (html, htm, css, gif, jpg, png, ico, zip, ...)
- ./loadbalancer : nginx binary (executable) and all subfolders need to be placed here
- ./logs : log files of the webserver instances (pwsh_webserver_instance.ps1)
- ./plugins : plugins go here (basically, they are Powershell modules)


**Configuration**
1) edit config file ./loadbalancer/config/nginx.conf:
   config the loadbalancer, for example add more web instances, enable ip hasing, enable ssl.
2) subfolder ./content :
   place your website content here
3) Edit file pwsh_webserver_bootstrap.ps1:
   edit line $global:WebCount, to set the number of instances you want.
   edit line $global:WebStartPort, to define the start port of the first instance.
   edit line $global:LoadbalancerUseSSL. If $true (= https), if $false (= http).
4) Edit file pwsh_webserver_instance.ps1:
   edit line $global:PublishLocalhost. If $true (= localhost only), if $false (= public).

Starting webserver instances in Powershell (*):
> .\pwsh_webserver_bootstrap.ps1 -start

Stopping running webserver instances in Powershell (*):
> .\pwsh_webserver_bootstrap.ps1 -stop

Restarting webserver instances in Powershell (*):
> .\pwsh_webserver_bootstrap.ps1 -reload

Verify webserver instances in Powershell:
> .\pwsh_webserver_bootstrap.ps1 -verify

Dump last 20 lines from nginx error.log in Powershell:
> .\pwsh_webserver_bootstrap.ps1 -error

Dump last 20 lines from nginx access.log in Powershell:
> .\pwsh_webserver_bootstrap.ps1 -access

Dump nginx.conf file from Powershell:
> .\pwsh_webserver_bootstrap.ps1 -config

Clean all log files from Powershell:
> .\pwsh_webserver_bootstrap.ps1 -clean

Reset webserver stack from Powershell:
> .\pwsh_webserver_bootstrap.ps1 -reset

(*) *Running a webserver on ports below 1024 (wel known ports), you must run Powershell (or pwsh) in Elevated mode (Windows) or Root (Linux) to listen on for example port tcp/80 and tcp/443.
Otherwise, you can just run it normally if it's for testing and running on port tcp/8080 or any of tcp/[1025-65535].*


**Provided plugins**
- Web.Cookies : plugin to handle session cookies
- Web.PostbackForms : basic plugin sample for form postback processing


**Examples included**
- http://localhost:<instance_port>/kill   :  route to shutdown the webserver
- http://localhost:<instance_port>/ping   :  route to ping the webserver (used with .\pwsh_webserver_bootstrap.ps1 -verify)
- http://localhost/cookie :  simple example with cookies
- http://localhost/       :  example index page, no markup
- http://localhost/someapp/someapp.html : example app to test image and css loading

Pieter De Ridder (Suglasp)
