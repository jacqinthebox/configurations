# Test Environment for a domain controller and two members

Deployment script works only on Windows. Todo: create azure-cli variant.

## How to use

Dot source it:

```powershell
./New-AzureDeploy.ps1
```

Then run it like this:

```powershell
import-module cChoco -Force
import-module xActiveDirectory -Force
import-module xNetworking -Force
Import-Module xPendingReboot -Force
Import-Module xStorage -Force

$vars = @{
    ClientId = "25892f7e-xxx"
    Secret = "NzA0u+xxxxxxxxx"
    TenantId = "63060cb1xxxxx"
    SubscriptionId = "3459c2bfxxx"
    ResourceGroupName = "scom-poc"
    ArtifactsResourceGroup = 'msdn-mct-deployments' 
    ArtifactsLocationStorageAccount = 'msdnmctartifacts'
}

# modify path if needed
.\New-AzureDeploy.ps1 @vars -Verbose
```

## Troubleshoot

```powershell
Login-AzureRmAccount
(Get-AzureRmLog -Status "Failed" | Select-Object -First 1) | Format-List
```


