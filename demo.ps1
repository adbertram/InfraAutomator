#region Scenario: 
<#
You're an DevOps pro and you need to build tooling for devs to deploy their own web servers in Azure. It's your job
to build an Azure DevOps pipeline that to support development of this tool using Terraform to build an Azure VM, configure
the VM with DSC and and run Pester tests to ensure the VM was built successfully.
#>
#endregion

#region Important links to note to build this yourself:
<#
Public GitHub repo: https://github.com/adbertram/infraautomator

Blog posts: https://adamtheautomator.com/azure-devops-piaz loginpeline-infrastructure
            https://adamtheautomator.com/terraform-azure/

Some resources I used used to build this project.

https://medium.com/modern-stack/bootstrap-a-vm-to-azure-automation-dsc-using-terraform-f2ba41d25cd2
https://docs.microsoft.com/en-us/azure/automation/automation-dsc-getting-started
https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line#creating-a-token
#>
#endregion

#region Assumptions/Prerequisites

<#
=============================
1. You have Terraform installed already on your local machine.
2. You're using PowerShell Core.
3. You have the InfrastructureAutomator GitHub repo cloned to your local machine.
4. You have a PAT generated in your GitHub repo. (to give the pipeline permission to access your repo)
5. You have the Azure PowerShell module installed and authenticated.
6. You have the Azure CLI installed and authenticated.

WARNING: Using this setup exactly as is WILL incur some Azure costs!
#>
#endregion

#region How this project will flow (and how you'd probably do it in the real world)
<#

===================

1. Lay out your plan.
    We want:
        - An Azure DevOps pipeline that will bring together various automation tasks
            - Deploy an Azure VM
            - Configure IIS on that VM with DSC
            - Run Pester tests to ensure everything is configured correctly

2. Build the initial infrastructure to support deploying the VM. This is done once. It will be done all with Terraform.
3. Build and test the Terraform config to deploy the VM manually.
4. Build the DSC configuration for the VM and onboard the VM to Azure State Configuration manually.
5. Build the Pester tests to test the VM deployment and DSC configuration steps.
6. Create an Azure pipeline for the VM deployment process linking Terraform, Azure State Configuration and Pester together.
#>
#endregion

#region Local development
## Here we will ensure we can build the VM, run the configuration and tests. Esentially, we're doing
## all of the steps locally before moving these into an AzDo pipeline

#region Build the initial infrastructure from scratch (one-time thing)

<# Goals: To create the following with Terraform:
    - Azure resource group
    - Azure virtual network with subnet
    - Azure automation account (for Azure State Configuration)
    - Azure network security group
    - Azure key vault with secrets for VM user and password (for storing secrets in the pipeline)
    - Azure DevOps project
    - Azure service endpoint for the pipeline to connect to the keyvault
    - Azure service endpoint for The AzDo project to connect to the GitHub repo
#>

## Change to the local-dev\env-setup folder and download Terraform providers
$repoWorkingDir = '/Users/adambertram/Dropbox/GitRepos/InfraAutomator'
Set-Location -Path "$repoWorkingDir\env_setup"
terraform init

#region Build and run the Terraform config

## Build the config (voila! It's already done!)

# open "$repoWorkingDir\local_dev\env_setup\main.tf"

## Set various env vars so we don't have to keep these sensitive keys in a config
$env:AZDO_PERSONAL_ACCESS_TOKEN = 'rbgwlw5dzdigftol6es5xfd2wd7nmylagkxadqsbj4334chry5ya'
$env:AZDO_ORG_SERVICE_URL = "https://dev.azure.com/adbertram/"

## Test the Terraform configuration
terraform plan --var-file=secrets.tfvars

## Create the infrastructure with Terraform (It's fast because it's already done!)
terraform apply --var-file=secrets.tfvars -auto-approve

## Note the network security group ID and subnet ID. We'll need those to build the VM. These are then placed in terraform.tfvars when
## build the VM

#endregion

#region Create all of the remaining components that Terraform cannot or received an error building

## Create the secrets to store the VM username/password
$kvName = 'infraautomator-keyvault'
az keyvault secret set --name vmAdminUsername --value 'adminuser' --vault-name $kvName
az keyvault secret set --name vmAdminPassword --value "I like azure." --vault-name $kvName

## Install the AzDo extension to the Azure CLI
az extension add --name azure-devops
az devops configure --defaults organization=https://dev.azure.com/adbertram project="Infrastructure Automator"

## GitHub endpoint for the pipeline to connect to the repo
$gitHubRepoUrl = 'https://github.com/adbertram/InfraAutomator'

## gitHubAccessToken = '2e151d195ac89a80584711bcda2ed90664573012'
$gitHubServiceEndpoint = az devops service-endpoint github create --github-url $gitHubRepoUrl --name 'GitHub' | ConvertFrom-Json

## Install Terraform extension in the org
## https://marketplace.visualstudio.com/items?itemName=charleszipp.azure-pipelines-tasks-terraform
az devops extension install --extension-id azure-pipelines-tasks-terraform --publisher-id "charleszipp"

## Install the Pester extension
az devops extension install --extension-id PesterRunner --publisher-id Pester

## Create the pipeline but don't run it yet
az pipelines create --name 'InfrastructureAutomator' --repository $gitHubRepoUrl --branch master --service-connection $gitHubServiceEndpoint.id --skip-run
## Set the visibility to public if not already created: https://dev.azure.com/adbertram/Infrastructure%20Automator/_settings/

## Allow the pipeline to read the keyvault. This isn't possible in Terraform
$serviceConnectionId = (az devops service-endpoint list | ConvertFrom-Json | where {$_.name -eq 'ARM'}).id
az devops service-endpoint update --id $serviceConnectionId --enable-for-all

# az keyvault set-policy --name $kvName --spn $spIdUri --secret-permissions get list

#endregion

## Create the DSC configuration (you could test this locally)

code "$repoWorkingDir\local-dev\vm_automation\iis.ps1"

#region Send the DSC configuration to Azure State Configuration

## Upload and import the DSC configuration (this is only done once)
$automationAcctName = 'dev-playground'
$azResourceGroup = 'dev_playground'
Import-AzAutomationDscConfiguration -AutomationAccountName $automationAcctName -ResourceGroupName $azResourceGroup -SourcePath "$repoWorkingDir/iis.ps1" -Published

## Remove a configuration (troubleshooting)
# Remove-AzAutomationDscConfiguration -Name iis -AutomationAccountName $automationAcctName -ResourceGroupName $azResourceGroup -Force

## Compile the DSC configuration
Start-AzAutomationDscCompilationJob -AutomationAccountName $automationAcctName -ResourceGroupName $azResourceGroup -ConfigurationName 'IIS'

#endregion

#endregion

#region Build the automation for the VM (repeatable)

Set-Location -Path $repoWorkingDir

## Build the Terraform config to deploy an Azure VM (this will go in the pipeline)
code 'main.tf'

## Test the Terraform config for the VM
terraform init
terraform plan --var-file=secrets.tfvars
terraform apply --var-file=secrets.tfvars -auto-approve

#endregion

#region Register the Azure VM with the Azure Automation DSC service
## This install the DSC extension, registers the node with Azure State Configuration and defines the configuration to use

## We will skip this part. It takes awhile. (10+ minutes) It's already been done
Register-AzAutomationDscNode -AutomationAccountName $automationAcctName -AzureVMName "VM-0" -ResourceGroupName $azResourceGroup -NodeConfigurationName "IIS.localhost"

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
#endregion

## Build the Pester tests to confirm both Terraform and DSC
$global:rgName = $azResourceGroup
$global:VmHostName = 'VM-0'

## Two "layers" of tests; one for the VM deployment and one for the configuration of the OS

## Open the /tests folder and kick off the tests (they take a bit)

Invoke-Pester -Path "$repoWorkingDir/tests"

#region Build the pipeline to put it all together
code "$repoWorkingDir\azure-pipelines.yml"

#endregion

#region Clean up the remnants
## Terraform destroy here for the VM and environment

Set-Location -Path $repoWorkingDir
terraform destroy --var-file=secrets.tfvars -auto-approve

Set-Location -Path "$repoWorkingDir\env_setup"
terraform destroy --var-file=secrets.tfvars -auto-approve

#endregion