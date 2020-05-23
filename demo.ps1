<#

Scenario: 

You're an DevOps pro and you need to build tooling for devs to create their own environments in Azure. Each envionment
consists of an Active Directory domain with a web server and a general member joined to the domain. It's your job
to build an Azure DevOps pipeline that to support development of this tool using Terraform to build the VMs, PowerShell
to configure the VMs and Pester to perform infrastructure testing.

Important concepts to note:

Public GitHub repo: https://github.com/adbertram/infraautomator
AzDo pipeline: https://dev.azure.com/adbertram/Infrastructure%20Automator

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

WARNING: Using this setup exactly as is WILL incur some cost!

#>

Invoke-Pester

$repoWorkingDir = '/Users/adam/Dropbox/GitRepos/InfraAutomator'

#region One-time local preparation tasks

#region Create an Azure service principal for Terraform to use

## Find your subscription ID
az account list --query [*].[name, id]

## Create the service principal with the Contributor role scoped to your subscription
$subscriptionId = 'xxxx-xxxxx-xxxxx'
$sp = az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscriptionId" -n InfrastructureAutomator | ConvertFrom-Json

#endregion

#endregion

#region Local development
## Here we will ensure we can build all of the necessary VMs, run the configuration and tests. Esentially, we're doing
## all of the steps locally before moving these into an AzDo pipeline

#region Download Azure RM Terraform provider
Set-Location -Path $repoWorkingDir
terraform init
#endregion

#region Test the Terraform configuration
terraform plan --var-file=secrets.tfvars
#endregion

#region Create the VMs with Terraform
terraform apply --var-file=secrets.tfvars
#endregion

#endregion

#region Environment cleanup

## Remove the service principal
## Is this necessary if using the Azure CLI????
$spId = ((az ad sp list --all | ConvertFrom-Json) | Where-Object { 'http://InfrastructureAutomator' -in $_.serviceprincipalnames }).objectId
az ad sp delete --id $spId
#endregion