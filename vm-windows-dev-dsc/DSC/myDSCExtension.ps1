Configuration Main
{

Param ( [string] $nodeName )

Import-DscResource -ModuleName PSDesiredStateConfiguration, cChoco, xPendingReboot

Node $nodeName
  {
	  LocalConfigurationManager
	  {

		  RebootNodeIfNeeded = $True
	  }
	  
	  
	  cChocoInstaller installChoco
		{
			InstallDir = "c:\choco"
		}
       

		cChocoPackageInstaller notepadplusplus
		{
			Name        = "notepadplusplus"
			DependsOn   = "[cChocoInstaller]installChoco"
		}

	 
	  cChocoPackageInstaller installSumatra
		{
			Name = "sumatrapdf.install"
			DependsOn = "[cChocoInstaller]installChoco"
		}
		
		cChocoPackageInstaller installVisualStudio
		{
   
          Name = "visualstudio2015professional"
          DependsOn = "[cChocoInstaller]installChoco"
     
        }

	  xPendingReboot RebootAfterVisualStudio {

		  Name = "RebootAfterVisualStudio"
		  DependsOn = "[cChocoPackageInstaller]installVisualStudio"
	  }
	  cChocoPackageInstaller installVisualStudioCode
		{
   
          Name = "visualstudiocode"
          DependsOn = "[cChocoInstaller]installChoco"
     
        }







  }
}