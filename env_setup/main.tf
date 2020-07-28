provider "azurerm" {
  version = "=2.5.0"
  features {}
}

provider "azuredevops" {
  version = ">= 0.0.1"
}

variable "rg_name" {
  type = string
}

variable "vmAdminPassword" {
  type = string
}

variable "vmAdminUsername" {
  type = string
}

variable "gh_service_endpoint_name" {
  type = string
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_automation_account" "dev-playground" {
  name                = "dev-playground"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "Basic"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "env-access"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "winrm-http"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azuredevops_serviceendpoint_azurerm" "endpointazure" {
  project_id                = azuredevops_project.project.id
  service_endpoint_name     = "ARM"
  azurerm_spn_tenantid      = data.azurerm_client_config.current.tenant_id
  azurerm_subscription_id   = data.azurerm_client_config.current.subscription_id
  azurerm_subscription_name = data.azurerm_subscription.current.display_name
}

resource "azurerm_key_vault" "vault" {
  name                            = "infraautomator-keyvault"
  depends_on                      = [azuredevops_serviceendpoint_azurerm.endpointazure]
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled             = false
  purge_protection_enabled        = false
  sku_name                        = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "set",
      "get",
      "list"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azuredevops_serviceendpoint_azurerm.endpointazure.id

    secret_permissions = [
      "get",
      "list"
    ]
  }
}

## Commenting to create via AZ CLI due to this error when the key vault secrets do not already exist. 
##  May be related to the vault being in a deleted state and not removed?
## Error: A resource with the ID "https://infraautomator-keyvault.vault.azure.net/secrets/vmAdminUsername/7076633116e84041ac3b90e9473ecd69"
## already exists - to be managed via Terraform this resource needs to be imported into the State. Please see the resource documentation
## for "azurerm_key_vault_secret" for more information.
# resource "azurerm_key_vault_secret" "vmAdminUsername" {
#   name         = "vmAdminUsername"
#   value        = var.vmAdminUsername
#   key_vault_id = azurerm_key_vault.vault.id
# }

# resource "azurerm_key_vault_secret" "vmAdminPassword" {
#   name         = "vmAdminPassword"
#   value        = var.vmAdminPassword
#   key_vault_id = azurerm_key_vault.vault.id
# }

resource "azuredevops_project" "project" {
  project_name        = "Infrastructure Automator"
  description = "Supporting pipeline for the Azure DevOps Pipelines for the Infrastructure Automator PowerShell Saturday Chicago conference talk"
}



## Getting error "Github Apps must be created on Github and then can be imported". We're using a personal access token
# resource "azuredevops_serviceendpoint_github" "gh_endpoint" {
#   project_id            = azuredevops_project.project.id
#   service_endpoint_name = var.gh_service_endpoint_name

#   # auth_personal {
#   #   personal_access_token = var.AZDO_GITHUB_SERVICE_CONNECTION_PAT
#   # }
# }

output "subnet_id" {
  value       = azurerm_subnet.subnet.id
}

output "nsg_id" {
  value       = azurerm_network_security_group.nsg.id
}