<#

Scenario: 

You're an DevOps pro and you need to build tooling for devs to create their own environments in Azure. Each envionment
consists of an Active Directory domain with a web server and a general member joined to the domain. It's your job
to build an Azure DevOps pipeline that to support development of this tool using Terraform to build the VMs, PowerShell
to configure the VMs and Pester to perform infrastructure testing.

Important concepts to note:

Public GitHub repo: https://github.com/adbertram/infraautomator
Blog post: https://adamtheautomator.com/azure-devops-pipeline-infrastructure
https://adamtheautomator.com/terraform-azure/

3 VMs:
 - VM-0 (DC)
 - VM-1 (WEBSRV)
 - VM-2 (APPSRV)




Assumptions
============
1. You have the Azure CLI installed and authenticated to Azure
2. You have Terraform already on your machine.
3. You're using PowerShell Core.
4. You have the GitHub repo cloned to $repoWorkingDir
5. You have a PAT generated in your GitHub repo (https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line#creating-a-token)

WARNING: Using this setup exactly as is WILL incur some cost!

#>

## Test demo environment so everything is in place
Invoke-Pester

$repoWorkingDir = '/Users/adam/Dropbox/GitRepos/InfraAutomator'
$azResourceGroup = 'dev_playground'
$azRegion = 'eastus'
$projectName = 'InfrastructureAutomator'
$azDoOrgName = 'https://dev.azure.com/adbertram'

#region Local development
## Here we will ensure we can build all of the necessary VMs, run the configuration and tests. Esentially, we're doing
## all of the steps locally before moving these into an AzDo pipeline

#region Terraform configuration

#region Download Azure RM Terraform provider
Set-Location -Path $repoWorkingDir
terraform init
#endregion

#region Test the Terraform configuration
terraform plan --var-file=secrets.tfvars
#endregion

#region Create the infrastructure with Terraform
terraform apply --var-file=secrets.tfvars
#endregion

#endregion

#region PowerShell code and Pester tests

## Here is where we will create and test the code to configure all of the VMs and build the infrastructure Pester tests

## Connecting to each VM with PS Remoting

## Configuring each VM

## Pester tests the pipeline will eventually invoke automatically

#endregion

#endregion

#region Moving all local dev efforts to AzDo

#region Prep the local dev environment for the pipeline

## Remove the secrets.tfvars because we'll be using the Azure Key Vault for that
Remove-Item -Path "$repoWorkingDir\secrets.tfvars"

## Update the main configuration to not include secrets

#endregion

#region Variable assignments

## These vars will be used throughout to set everything up
$azSubscriptionName = 'Adam the Automator'
$azDoOrgName = 'https://dev.azure.com/adbertram'
$azRegion = 'eastus'
$projectName = 'InfrastructureAutomator'
$azRgName = $projectName
$azDoProjectName = $projectName
$gitHubRepoUrl = 'https://github.com/adbertram/InfrastructureAutomator'
$azPipelineName = $projectName

az account list --query [*].[name, id]
$azSubscriptionId = 'xxxx'
$azTenantId = 'xxxxx'

#endregion

#region Install the Azure CLI DevOps extension to build AzDo from the command line
az extension add --name azure-devops
az devops configure --defaults organization=$azDoOrgName
#endregion

#region Create the resource group

## This could be done with Terraform but we're going to add some resources to it that every deployment run will share
az group create --location $azRegion --name $azRgName

#endregion

#region Create a service principal
## This will be how the pipeline authenticates to your subscription
$spIdUri = "http://$projectName"
$sp = az ad sp create-for-rbac --name $spIdUri | ConvertFrom-Json
#endregion

#region Create the keyvault and add secrets
## They keyvault holds all of the sensitive information the pipeline will use
$kvName = "$projectName-KV"
az keyvault create --location $region --name $kvName --resource-group $azRgName --enabled-for-template-deployment true

## Create the secrets to store the VM username/password
az keyvault secret set --name VMAdminUsername --value 'dev_admin' --vault-name $kvName
az keyvault secret set --name VmAdminPassword --value "I like azure." --vault-name $kvName

## allow the pipeline to access the key vault
az keyvault set-policy --name $kvName --spn $spIdUri --secret-permissions get list

#endregion

#region Create the AzDo project
az devops project create --name $azDoProjectName

## Set the project default so we don't have to specify it every time
az devops configure --defaults project=$azDoProjectName
#endregion

#region Install Terraform extension
## https://marketplace.visualstudio.com/items?itemName=charleszipp.azure-pipelines-tasks-terraform
az devops extension install --extension-id Terraform --publisher-id "Charles Zipp"
#endregion

#region Create service connection and configure pipeline to use
## Run $sp.password and copy it to the clipboard
$sp.Password

## for the pipeline to auth to subscription
az devops service-endpoint azurerm create --azure-rm-service-principal-id $sp.appId --azure-rm-subscription-id $azSubscriptionId --azure-rm-subscription-name $azSubscriptionName --azure-rm-tenant-id $azTenantId --name 'ARM'

## pipeline to auth to GitHub
$gitHubServiceEndpoint = az devops service-endpoint github create --github-url $gitHubRepoUrl --name 'GitHub' | ConvertFrom-Json

#endregion

#region Create the pipeline but don't run it yet
az pipelines create --name $azPipelineName --repository $gitHubRepoUrl --branch master --service-connection $gitHubServiceEndpoint.id --skip-run
#endregion

#region Environment cleanup

## Remove the service principal
$spId = ((az ad sp list --all | ConvertFrom-Json) | Where-Object { 'http://InfrastructureAutomator' -in $_.serviceprincipalnames }).objectId
az ad sp delete --id $spId
#endregion