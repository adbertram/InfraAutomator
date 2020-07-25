<#
Scenario: 

You're an DevOps pro and you need to build tooling for devs to deploy their own web servers in Azure. It's your job
to build an Azure DevOps pipeline that to support development of this tool using Terraform to build an Azure VM, configure
the VM with DSC and and run Pester tests to ensure the VM was built successfully.

#>

<#
Important links to note to build this yourself:

Public GitHub repo: https://github.com/adbertram/infraautomator

Blog posts: https://adamtheautomator.com/azure-devops-piaz loginpeline-infrastructure
            https://adamtheautomator.com/terraform-azure/
#>

<#

Some resources I used used to build this project.

https://medium.com/modern-stack/bootstrap-a-vm-to-azure-automation-dsc-using-terraform-f2ba41d25cd2
https://docs.microsoft.com/en-us/azure/automation/automation-dsc-getting-started
https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line#creating-a-token

#>

<#
Assumptions/Prerequisites
=============================
1. You have the Azure CLI installed and authenticated to Azure
2. You have Terraform installed already on your local machine.
3. You're using PowerShell Core.
4. You have the InfrastructureAutomator GitHub repo cloned to $repoWorkingDir
5. You have a PAT generated in your GitHub repo
6. You have the Azure PowerShell module installed and authenticated.

WARNING: Using this setup exactly as is WILL incur some cost!
#>

<#
How this project will flow (and how you'd probably do it in the real world)
===================

1. Lay out your plan.
    We want:
        - An Azure DevOps pipeline that will bring together various automation tasks
            - Deploy an Azure VM
            - Configure IIS on that VM with DSC
            - Run Pester tests to ensure everything is configured correctly
2. Build each component one at a time.
    - Build and test the Terraform configuration to create the Azure VM
    - Build and test the Pester tests to confirm the Azure VM creation
    - Build and test the DSC configuration to do whatever you need post-VM deployment (IIS)
    - Build and test the Pester tesets to confirm what DSC did
3. Create an AzDo pipepeline
4. Move all local dev work into the pipeline

#>

#region Define all of the variables to use throughout the demo
$repoWorkingDir = '/Users/adambertram/Dropbox/GitRepos/InfraAutomator'
$azResourceGroup = 'dev_playground'
$azRegion = 'eastus'
$automationAcctName = 'dev-playground'
#endregion

#region Local development
## Here we will ensure we can build the VM, run the configuration and tests. Esentially, we're doing
## all of the steps locally before moving these into an AzDo pipeline

#region Terraform configuration

#region Download Azure RM Terraform provider
Set-Location -Path "$repoWorkingDir\local-dev"
terraform init
#endregion

## Build the config (voila! It's already done!)

#region Test the Terraform configuration
terraform plan --var-file=secrets.tfvars
#endregion

#region Create the infrastructure with Terraform (It's fast because it's already done!)
terraform apply --var-file=secrets.tfvars
#endregion

#endregion

#region Create the DSC configuration

## Voila! It's already done!

#endregion

#region Upload the DSC config to Azure State Configuration

## Upload and import the DSC configuration (this is only done once)
Import-AzAutomationDscConfiguration -AutomationAccountName $automationAcctName -ResourceGroupName $azResourceGroup -SourcePath "$repoWorkingDir/iis.ps1" -Published

## Remove a configuration (troubleshooting)
# Remove-AzAutomationDscConfiguration -Name iis -AutomationAccountName $automationAcctName -ResourceGroupName $azResourceGroup -Force

## Compile the DSC configuration
Start-AzAutomationDscCompilationJob -AutomationAccountName $automationAcctName -ResourceGroupName $azResourceGroup -ConfigurationName 'IIS'

#endregion

#region Register the Azure VM with the Azure Automation DSC service

## This install the DSC extension, registers the node with Azure State Configuration and defines the configuration to use
Register-AzAutomationDscNode -AutomationAccountName $automationAcctName -AzureVMName "VM-0" -ResourceGroupName $azResourceGroup -NodeConfigurationName "IIS.localhost"
#endregion

<# Troubleshooting steps in case you run into problems
Register-AzAutomationDscNode: One or more errors occurred. (Long running operation failed with status 'Failed'. Additional Info:'
At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/DeployOperations for usage details.')

"VERBOSE: [2020-07-25 14:43:56Z] [ERROR] Registration of the Dsc Agent with the server 
https://c891d501-7968-4224-8331-3fa264659942.agentsvc.eus.azure-automation.net/accounts/c891d501-7968-4224-8331-3fa2646
59942 failed. The underlying error is: Failed to register Dsc Agent with AgentId 85C4A0FC-CDDC-11EA-8B75-000D3A9A222C 
with the server 
https://c891d501-7968-4224-8331-3fa264659942.agentsvc.eus.azure-automation.net/accounts/c891d501-7968-4224-8331-3fa2646
59942/Nodes(AgentId='85C4A0FC-CDDC-11EA-8B75-000D3A9A222C'). ."

Help: https://docs.microsoft.com/en-us/azure/automation/troubleshoot/desired-state-configuration
https://docs.microsoft.com/id-id/azure///automation/troubleshoot/desired-state-configuration

Troubleshotoing tips: log files on VM:
 C:\Packages\Plugins\Microsoft.PowerShell.DSC\<type handler version>\Status\1.status
 C:\WindowsAzure\Logs\Plugins\Microsoft.PowerShell.DSC\<type handler version>\

 The VM must have Internet access!!
#>

#region Build Pester tests

## Voila! Already built!

Invoke-Pester "$repoWorkingDir\tests\vm.tests.ps1"

#endregion

#endregion

#region Moving all local dev efforts to AzDo

#region Prep the local dev environment for the pipeline

## Update the main configuration to not include secrets. These will come from the KeyVault in Azure

#endregion

#region Build the pipeline

## Voila! Already done in azure-pipelines.yml

#endregion

#region Add the VM admin user and password to the Azure KeyVault

## Voila! Already done.

#region If you want to build this yourself
## They keyvault holds all of the sensitive information the pipeline will use
$kvName = 'keyvault'
az keyvault create --location $azRegion --name $kvName --resource-group $azResourceGroup --enabled-for-template-deployment true
#endregion

#region If you want to build this yourself

$kvName = 'keyvault'
## Create the secrets to store the VM username/password
az keyvault secret set --name vmAdminUsername --value 'adminuser' --vault-name $kvName
az keyvault secret set --name vmAdminPassword --value "I like azure." --vault-name $kvName

## This will be how the pipeline authenticates to your subscription
$spIdUri = "http://dev_playground"
$sp = az ad sp create-for-rbac --name $spIdUri | ConvertFrom-Json

## allow the pipeline to access the key vault
az keyvault set-policy --name $kvName --spn $spIdUri --secret-permissions get list

$azDoProjectName = 'dev_playground'
az devops project create --name $azDoProjectName

## Set the project default so we don't have to specify it every time
az devops configure --defaults project=$azDoProjectName

## Install Terraform extension
## https://marketplace.visualstudio.com/items?itemName=charleszipp.azure-pipelines-tasks-terraform
az devops extension install --extension-id Terraform --publisher-id "Charles Zipp"

## Create service connection and configure pipeline to use
## Run $sp.password and copy it to the clipboard
$sp.Password

## for the pipeline to auth to subscription
$azSubscriptionId = 'xxxx' ## az account list --query [*].[name, id]
$azSubscriptionName = 'Adam the Automator'
$azTenantId = 'xxxxx'

az devops service-endpoint azurerm create --azure-rm-service-principal-id $sp.appId --azure-rm-subscription-id $azSubscriptionId --azure-rm-subscription-name $azSubscriptionName --azure-rm-tenant-id $azTenantId --name 'ARM'

## pipeline to auth to GitHub
$gitHubRepoUrl = 'https://github.com/adbertram/InfraAutomator'
$gitHubServiceEndpoint = az devops service-endpoint github create --github-url $gitHubRepoUrl --name 'GitHub' | ConvertFrom-Json

## Create the pipeline but don't run it yet
az pipelines create --name 'InfrastructureAutomator' --repository $gitHubRepoUrl --branch master --service-connection $gitHubServiceEndpoint.id --skip-run

#endregion


#region Environment cleanup

## Remove the service principal
$spId = ((az ad sp list --all | ConvertFrom-Json) | Where-Object { 'http://InfrastructureAutomator' -in $_.serviceprincipalnames }).objectId
az ad sp delete --id $spId
#endregion