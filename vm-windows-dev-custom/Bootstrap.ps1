﻿Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
Install-PackageProvider -Name Nuget -Force

$software = @(
    'visualstudiocode'
    'git',
    'conemu',
    'googlechrome',
    'notepadplusplus',
    'conemu',
    'soapui',
    'visualstudio2017enterprise',
    'resharper'
)


foreach ($s in  $software) {
    choco install $s -yes
}

Install-Module posh-git -Scope CurrentUser -Force
Install-Module oh-my-posh -Scope CurrentUser -Force
Install-Module ISESteroids -Scope CurrentUser -Force
Invoke-WebRequest https://github.com/jacqinthebox/packer-templates/blob/master/extras/devmachine/Meslo%20LG%20M%20DZ%20Regular%20for%20Powerline.ttf?raw=true -OutFile ~\Desktop\Meslo.ttf
