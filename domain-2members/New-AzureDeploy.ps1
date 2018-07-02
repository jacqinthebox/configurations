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

        [string]
        $DeploymentName,

        [Parameter(Mandatory = $True)]
        [string]
        $ArtifactsResourceGroup, 
      
        [Parameter(Mandatory = $True)]
        [string]
        $ArtifactsLocationStorageAccount,

        [string]
        $ResourceGroupLocation = "west europe",
    
        [string]
        $RegisterProviders = $True,

        [string] 
        $DSCSourceFolder = 'DSC',

        [string]
        $TemplateFilePath = "template.json",

        [string]
        $ParametersFilePath = "parameters.json"
    )

    # Give the Deployment a unique name
    $DeploymentName = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"

    # Helper function to register resources in your subscription
    Function RegisterResourceProviders {
        Param(
            [string]$ResourceProviderNamespace
        )

        Write-Host "Registering resource provider '$ResourceProviderNamespace'";
        Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
    }

    # Helper function to login
    Function LogIn {
        $azurePassword = ConvertTo-SecureString $secret -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($clientId, $azurePassword)
        Login-AzureRmAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal
    }

    
    $ErrorActionPreference = "Stop"

    Write-Verbose "Logging in...";
    LogIn
    
    # Staging artificats resource group
    Write-Verbose "Creating a resource group, storage account and container to store the staging artifacts"
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $ArtifactsLocationStorageAccount})

    If ($StorageAccount -eq $null) {
    
        New-AzureRmResourceGroup -Name $ArtifactsResourceGroup -Location $ResourceGroupLocation
        New-AzureRmStorageAccount -ResourceGroupName $ArtifactsResourceGroup -Name $ArtifactsLocationStorageAccount -Type Standard_LRS -Location "westeurope"
        Set-AzureRmCurrentStorageAccount -ResourceGroupName $ArtifactsResourceGroup -Name $ArtifactsLocationStorageAccount 
        $containers = Get-AzureStorageContainer | Where-Object { $_.Name -eq 'templates'} 
        if ($containers -eq $null) {
            New-AzureStorageContainer -Name templates -Permission Off
        }
   
    }

    # Register providers (if needed)
    if ($registerProviders -eq $True) {
        $resourceProviders = @("microsoft.compute", "microsoft.devtestlab", "microsoft.network", "microsoft.storage");
        if ($resourceProviders.length) {
            Write-Host "Registering resource providers"
            foreach ($resourceProvider in $resourceProviders) {
                RegisterResourceProviders($resourceProvider);
            }
        }
    }

    # Create or get the storage account for deployments
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $ArtifactsLocationStorageAccount})

    If ($StorageAccount -eq $null) {
    
        New-AzureRmResourceGroup -Name $ArtifactsResourceGroup -Location "westeurope"
        New-AzureRmStorageAccount -ResourceGroupName $ArtifactsResourceGroup -Name $ArtifactsLocationStorageAccount -Type Standard_LRS -Location "westeurope"
    }
        
    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
        }
    }

    # Uploading files including DCS folder
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $ArtifactsResourceGroup -Name $ArtifactsLocationStorageAccount 
    $artifactsPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '.'))

    $container = Get-AzureStorageContainer -Name templates 
    if ($container -eq $null) {
        New-AzureStorageContainer -Name templates -Permission Off 
    }

    $files = Get-ChildItem -Path $artifactsPath -Recurse -File | ForEach-Object -Process { $_.FullName}
    
    foreach ($f in $files) {
        Set-AzureStorageBlobContent -File $f -Blob $f.Substring($ArtifactsPath.length + 1) -Container templates -Context $artifactsPath.Context -Force
    }


    # Create or check for existing resource group to deploy in
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

    # Create s Sas Token
    Write-Verbose "We need to create a SAS token first"
    $token = New-AzureStorageContainerSASToken -Name templates -Permission r -ExpiryTime (Get-Date).AddHours(2)
    $url = (Get-AzureStorageBlob -Container templates -Blob $templateFilePath).ICloudBlob.uri.AbsoluteUri
 
    # Convert the parameters file to a hash table
    Write-Verbose "We need to extract the parameters from the parameters file and convert them to a hash for splatting"
    $absoluteParametersPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ParametersFilePath))
    $OptionalParameters = @{}
    $json = get-content $absoluteParametersPath
    $psObject = $json | ConvertFrom-Json
    
    $psObject.parameters | get-member -type NoteProperty | Foreach-Object {
        $value = ($psObject.parameters.$($_.Name)).value
        $optionalParameters.Add($_.Name, $value)
    }

    # and add the Sas Token to the hash table
    Write-Verbose "We need to add the token to our parameters hash"
    $OptionalParameters['artifactsLocationSasToken'] = $token
    $OptionalParameters['artifactsLocationStorageAccount'] = $ArtifactsLocationStorageAccount
    
    Write-Verbose ($url + $token)
    
    # Now everything is in place to start the deployment of the ARM template
    Write-Verbose "Starting deployment..."
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateUri ($url + $token) @OptionalParameters

