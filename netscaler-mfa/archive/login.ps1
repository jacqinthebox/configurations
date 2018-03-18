$clientId = ""
$secret = ""
$azurePassword = ConvertTo-SecureString $secret -AsPlainText -Force
$tenantId = ""
$psCred = New-Object System.Management.Automation.PSCredential($clientId, $azurePassword)
Add-AzureRmAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal

# New Storage account for articacts
$deploymentResourceGroup = 'msdn-mct-deployments' 
$deploymentStorageAccountname = 'msdnmctartifacts'

$StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $deploymentStorageAccountName})

If ($StorageAccount -eq $null) {
    
    New-AzureRmResourceGroup -Name $deploymentResourceGroup -Location "westeurope"
    New-AzureRmStorageAccount -ResourceGroupName $deploymentResourceGroup -Name $deploymentStorageAccountname -Type Standard_LRS -Location "westeurope"
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $deploymentResourceGroup -Name $deploymentStorageAccountname 
}

New-AzureStorageContainer -Name templates -Permission Off
