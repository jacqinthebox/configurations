Function New-AzureDeployment {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]
        $SubscriptionId,

        [Parameter(Mandatory = $True)]
        [string]
        $ClientId,

        [Parameter(Mandatory = $True)]
        [string]
        $Secret,

        [Parameter(Mandatory = $True)]
        [string]
        $TenantId,

        [Parameter(Mandatory = $True)]
        [string]
        $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [string]
        $DeploymentName,

        [Parameter(Mandatory = $True)]
        [string]
        $DeploymentResourceGroup, 
      
        [Parameter(Mandatory = $True)]
        [string]
        $DeploymentStorageAccountname,

        [string]
        $ResourceGroupLocation = "west europe",
    
        [string]
        $RegisterProviders = $False,

        [string]
        $TemplateFilePath = "template.json",

        [string]
        $ParametersFilePath = "parameters.json"
    )

    Function RegisterResourceProviders {
        Param(
            [string]$ResourceProviderNamespace
        )

        Write-Host "Registering resource provider '$ResourceProviderNamespace'";
        Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
    }

    Function LogIn {
        $azurePassword = ConvertTo-SecureString $secret -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($clientId, $azurePassword)
        Login-AzureRmAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal
    }

    
    $ErrorActionPreference = "Stop"

    Write-Verbose "Logging in...";
    LogIn;
    
    if ($registerProviders -eq $True) {
        $resourceProviders = @("microsoft.compute", "microsoft.devtestlab", "microsoft.network", "microsoft.storage");
        if ($resourceProviders.length) {
            Write-Host "Registering resource providers"
            foreach ($resourceProvider in $resourceProviders) {
                RegisterResourceProviders($resourceProvider);
            }
        }
    }

    # A storage account for deployments
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $deploymentStorageAccountName})

    If ($StorageAccount -eq $null) {
    
        New-AzureRmResourceGroup -Name $deploymentResourceGroup -Location "westeurope"
        New-AzureRmStorageAccount -ResourceGroupName $deploymentResourceGroup -Name $deploymentStorageAccountname -Type Standard_LRS -Location "westeurope"
    }

    # uploading files 
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $deploymentResourceGroup -Name $deploymentStorageAccountname 
    $artifactsPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '.'))

    $container = Get-AzureStorageContainer -Name templates 
    if ($container -eq $null) {
        New-AzureStorageContainer -Name templates -Permission Off 
    }

    $files = Get-ChildItem -Path $artifactsPath -Recurse -File | ForEach-Object -Process { $_.FullName}
    
    foreach ($f in $files) {
        # $fileName = $f.Name
        # Set-AzureStorageBlobContent -Container templates -File "$artifactsPath\$fileName" -Force
        Set-AzureStorageBlobContent -File $f -Blob $f.Substring($ArtifactsPath.length + 1) -Container templates -Context $artifactsPath.Context -Force
    }


    # Actual deployment. Create or check for existing resource group
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        Write-Verbose "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
        if (!$resourceGroupLocation) {
            $resourceGroupLocation = Read-Host "resourceGroupLocation";
        }
        Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
        New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
    }
    else {
        Write-Verbose "Using existing resource group '$resourceGroupName'";
    }

    
    Write-Verbose "We need to create a SAS token first"
    $token = New-AzureStorageContainerSASToken -Name templates -Permission r -ExpiryTime (Get-Date).AddHours(2)
    $url = (Get-AzureStorageBlob -Container templates -Blob $templateFilePath).ICloudBlob.uri.AbsoluteUri
 
    Write-Verbose "We need to add the token to our parameters file"
    $absoluteParametersPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ParametersFilePath))
   
    $a = Get-Content $absoluteParametersPath -raw | ConvertFrom-Json 
    $sasTokenValue = $a | Select-Object -expand parameters | Select-Object -expand containerSasToken 
    $sasTokenValue.value = $token
    $a | ConvertTo-Json  | set-content $absoluteParametersPath

    Write-Verbose "Starting deployment..."
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateUri ($url + $token) -TemplateParameterFile $absoluteParametersPath
    
}

$vars = @{
    ClientId                     = ""
    Secret                       = ""
    TenantId                     = ""
    SubscriptionId               = ""
    DeploymentName               = "ParameterTest"
    ResourceGroupName            = "advanced-arm-template"
    DeploymentResourceGroup      = 'msdn-mct-deployments' 
    DeploymentStorageAccountname = 'msdnmctartifacts'
}

New-AzureDeployment @vars -Verbose


