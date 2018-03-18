wevtutil.exe set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:true
wevtutil.exe set-log "Microsoft-Windows-Dsc/Debug" /q:True /e:true
Install-PackageProvider -Name Nuget -Force -Confirm:$False -RequiredVersion 2.8.5.201
Install-Module -Name cChoco -Force
Limit-EventLog -LogName Application -MaximumSize 1GB
New-Item -Path HKLM:\SOFTWARE\MyCustomKeys\ApplicationLogIncreased -Force
