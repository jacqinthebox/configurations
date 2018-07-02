configuration CreateDC
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,
	
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCredentials,

        [Int]$RetryCount = 20,
        [Int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName xActiveDirectory, xNetworking, PSDesiredStateConfiguration, xPendingReboot, cChoco
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($AdminCredentials.UserName)", $AdminCredentials.Password)
    $Interface = Get-NetAdapter|Where-Object Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
             

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

		
        WindowsFeature DNS {
            Ensure = "Present"
            Name   = "DNS"
        }

        WindowsFeature DnsTools {
            Ensure    = "Present"
            Name      = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = '127.0.0.1'
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }

        WindowsFeature ADDSInstall {
            Ensure    = "Present"
            Name      = "AD-Domain-Services"
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature ADDSTools {
            Ensure    = "Present"
            Name      = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
	
        xADDomain FirstDS
        {
            DomainName                    = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DependsOn                     = @("[WindowsFeature]ADDSInstall")
        }

        xPendingReboot RebootAfterPromotion {
            Name      = "RebootAfterPromotion"
            DependsOn = "[xADDomain]FirstDS"
        }

        cChocoInstaller installChoco {
            InstallDir = "c:\choco"
            DependsOn  = "[xPendingReboot]RebootAfterPromotion"
        }

        cChocoPackageInstaller notepadplusplus {
            Name      = "notepadplusplus"
            DependsOn = "[cChocoInstaller]installChoco"
        }

        cChocoPackageInstaller firefox {
            Name      = "firefox"
            DependsOn = "[cChocoInstaller]installChoco"
        }
        
    }
}