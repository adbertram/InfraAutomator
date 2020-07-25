provider "azurerm" {
  version = "=2.5.0"
  features {}
}

variable "envName" {
  type = string
}

variable "vmAdminUsername" {
  type = string
}

variable "vmAdminPassword" {
  type = string
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.envName
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.envName}-vNet"
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

resource "azurerm_public_ip" "pubIp" {
  name                = "pubIp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "vnic" {
  name                = "vnic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.5"
    public_ip_address_id          = azurerm_public_ip.pubIp.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg-assoc" {
  network_interface_id      = azurerm_network_interface.vnic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "vm-0"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_F2"
  admin_username        = var.vmAdminUsername
  admin_password        = var.vmAdminPassword
  network_interface_ids = [azurerm_network_interface.vnic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

## Not using this method because you will receive the message: Error: A resource with the ID "/subscriptions/XXXXX/providers/Microsoft.Compute/virtualMachines/vm-0/extensions/dsc" 
## already exists - to be managed via Terraform this resource needs to be imported into the State. Please see the resource documentation
## for "azurerm_virtual_machine_extension" for more information." To ensure no manual intervention is required, moving this to the pipeline.

## This also throws an error about a missing tuple if the Azure VM isn't already created which appears to be a bug.

# resource "azurerm_virtual_machine_extension" "dsc" {
#   name                  = "dsc"
#   virtual_machine_id  = azurerm_windows_virtual_machine.vm.id
#   publisher             = "Microsoft.Powershell"
#   type                  = "DSC"
#   type_handler_version  = "2.73"
#   depends_on            = [azurerm_windows_virtual_machine.vm]

#   settings = <<SETTINGS
#         {
#             "WmfVersion": "latest",
#             "ModulesUrl": "https://eus2oaasibizamarketprod1.blob.core.windows.net/automationdscpreview/RegistrationMetaConfigV2.zip",
#             "ConfigurationFunction": "RegistrationMetaConfigV2.ps1\\RegistrationMetaConfigV2",
#             "Privacy": {
#                 "DataCollection": ""
#             },
#             "Properties": {
#                 "RegistrationKey": {
#                   "UserName": "PLACEHOLDER_DONOTUSE",
#                   "Password": "PrivateSettingsRef:registrationKeyPrivate"
#                 },
#                 "RegistrationUrl": "${var.dsc_endpoint}",
#                 "NodeConfigurationName": "iis_setup",
#                 "ConfigurationMode": "Apply",
#                 "ConfigurationModeFrequencyMins": 15,
#                 "RefreshFrequencyMins": 30,
#                 "RebootNodeIfNeeded": false,
#                 "ActionAfterReboot": "continueConfiguration",
#                 "AllowModuleOverwrite": false
#             }
#         }
#     SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#     {
#       "Items": {
#         "registrationKeyPrivate" : "${var.dsc_key}"
#       }
#     }
# PROTECTED_SETTINGS
# }

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

resource "azurerm_key_vault" "vault" {
  name                        = "keyvault"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get",
    ]

    storage_permissions = [
      "get",
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

output "VM" {
  value       = "${zipmap(azurerm_windows_virtual_machine.vm.*.name, azurerm_public_ip.pubIp.*.ip_address)}"
  description = "Public IP of the VM"
}