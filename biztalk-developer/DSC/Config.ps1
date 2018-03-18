Configuration Main
{
    Param ( 
        [string]$NodeName,
        [string]$officeDeploymentToolkitUrl  
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, cChoco

    New-Item -ItemType directory -Path c:\Parameters -Force
    Set-Content -path "c:\Parameters\OdtUrl.txt" -Value $officeDeploymentToolkitUrl
  
   
    Node $NodeName
    {
        File InstallDir {
            DestinationPath = "c:\install"
            Ensure          = "present"
            Type            = "Directory"
        } 

        cChocoInstaller installChoco
        {
            InstallDir = "c:\choco"
        }
   
        cChocoPackageInstaller notepadplusplus
        {
            Name      = "notepadplusplus"
            DependsOn = "[cChocoInstaller]installChoco"
        }
 
        cChocoPackageInstaller installSumatra
        {
            Name      = "sumatrapdf.install"
            DependsOn = "[cChocoInstaller]installChoco"
        }
	
        cChocoPackageInstaller installSoapui
        {
            Name      = "soapui"
            DependsOn = "[cChocoInstaller]installChoco"
        }

        cChocoPackageInstaller install7zipcommandline
        {
            Ensure    = 'Present'
            Name      = "7zip.commandline"
            DependsOn = "[cChocoInstaller]installChoco"
        }

        cChocoPackageInstaller install7zipinstall
        {
            Name      = "7zip.install"
            DependsOn = "[cChocoInstaller]installChoco"
        }
        cChocoPackageInstaller firefoxInstall
        {
            Name      = "firefox"
            DependsOn = "[cChocoInstaller]installChoco"
        }
        cChocoPackageInstaller visualstudiocode
        {
            Name      = "visualstudiocode"
            DependsOn = "[cChocoInstaller]installChoco"
        }
        Log ExcelinstallLog {
            Message = "Starting to install Excel."
        }

        Script CreateExcelConfiguration {
            TestScript = {
                Test-Path "C:\Install\excel.xml"
            }
     
            GetScript  = { 
                return @{ 'result' = "OK"}
            }

            SetScript  = {
                $excel = @"
<Configuration>
<Add SourcePath="c:\install\odt" OfficeClientEdition="32">
<Product ID="O365ProPlusRetail">
<Language ID="en-us" />
<ExcludeApp ID="Access" />
<ExcludeApp ID="Groove" />
<ExcludeApp ID="InfoPath" />
<ExcludeApp ID="Lync" />
<ExcludeApp ID="OneDrive" />
<ExcludeApp ID="OneNote" />
<ExcludeApp ID="Outlook" />
<ExcludeApp ID="PowerPoint" />
<ExcludeApp ID="Project" />
<ExcludeApp ID="Publisher" />
<ExcludeApp ID="SharePointDesigner" />
<ExcludeApp ID="Visio" />
<ExcludeApp ID="Word" />
</Product>
</Add>
<Display Level="None" AcceptEULA="TRUE" />  
</Configuration>
"@
                Set-Content -path "c:\install\excel.xml" -Value $excel  
  
            }
        }

        Script GetOdt {     
                GetScript  = {
                    $downloaded = "C:\install\officedeploymenttool.exe"
                    return @{ Result = $downloaded }
                }
           
            TestScript = {
              return Test-Path "C:\install\officedeploymenttool.exe"
            }
 
            SetScript  = {
                New-Item -ItemType Directory c:\Install\odt -force
                $Odt = Get-Content 'c:\parameters\odturl.txt'
                Write-Verbose $odt
                Invoke-WebRequest -Uri $Odt -OutFile C:\install\officedeploymenttool.exe
                Start-Sleep -s 10
            }
            DependsOn  = "[Script]CreateExcelConfiguration" 
        }

        Script ExtractOffice2016 {     
                GetScript  = {
                    $extracted = "C:\install\odt\Office\Data\16.0.8201.2209\i640.cab"
                    return @{ Result = $extracted }
                }
           
            TestScript = {
                $result = $False
                $kb = Get-ChildItem C:\install -Recurse | Measure-Object -Property Length -sum
                $size = [math]::Round(($kb.sum/1000000))
                if ($size -gt 1700) {
                  $result = $True
                }
                return $result
            }
 
            SetScript  = {
                set-location c:\install
                $preArglist = '/quiet /extract:c:\install'
                Start-Process -FilePath c:\install\officedeploymenttool.exe $preArglist -Wait -NoNewWindow

                $arglist = '/download excel.xml'
                Start-Process -FilePath c:\install\setup.exe -ArgumentList $arglist -Wait -NoNewWindow
            }
            DependsOn  = "[Script]GetOdt" 
        }
    
        Script InstallExcel2016 {     
            GetScript  = {
                $Result = Test-Path "C:\Program Files (x86)\Microsoft Office\root\Office16\EXCEL.EXE"
                return @{'result' = [string]$Result }
            }
      
            TestScript = {
                $Result = Test-Path "C:\Program Files (x86)\Microsoft Office\root\Office16\EXCEL.EXE"
                return $Result
            }
 
            SetScript  = {
                set-location c:\install
                $arglist = '/configure excel.xml'
                Start-Process -FilePath c:\install\setup.exe -ArgumentList $arglist -Wait -NoNewWindow
        
            }
            DependsOn  = "[Script]ExtractOffice2016" 
        }
        
        Script EnableTCPIP {
            
                  GetScript = {
                  @{Result = "EnableTCPIP"} }
                  SetScript = {
                    Get-CimInstance -Namespace root/Microsoft/SqlServer/ComputerManagement13 -ClassName ServerNetworkProtocol -Filter "InstanceName = 'MSSQLSERVER' and ProtocolName = 'Tcp'" | Invoke-CimMethod -Name SetEnable
                  }
                  TestScript = {
                    $cim = Get-CimInstance -Namespace root/Microsoft/SqlServer/ComputerManagement13 -ClassName ServerNetworkProtocol -Filter "InstanceName = 'MSSQLSERVER' and ProtocolName = 'Tcp'" 
                    Return $cim.Enabled
            
                  }
                }
                Script RestartTheServices
                {
                  GetScript = { 
                    @{Result = "RestartTheServices"} 
                  }
                  TestScript = { 
                    Return Test-Path 'c:\EnabledTcIp.txt'
                  }
                  SetScript = {
                    Start-Sleep -s 5
                    Stop-Service -Name 'MSSQLSERVER' -Force
                    Start-Sleep -s 5
                    Start-Service -Name 'MSSQLSERVER' 
                    Set-Content -Path 'c:\EnabledTcIp.txt' -value 'The SQL Service has been restarted'
                  }
                  DependsOn = "[Script]EnableTCPIP"
                }
               
    
        Log AllDoneLog {
            Message = "All Done"
        } 
    }
}