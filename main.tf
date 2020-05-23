provider "azurerm" {
  version = "=2.5.0"
  features {}
}

variable "labName" {
  type = string
}

variable "dcName" {
  type = string
}

variable "windowsClientName" {
  type = string
}

variable "linuxClientName" {
  type = string
}

variable "appSrvName" {
  type = string
}

variable "vmAdminUsername" {
  type = string
}

variable "vmAdminPassword" {
  type = string
}

resource "azurerm_resource_group" "rg" {
  name     = var.labName
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.labName}-vNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "labsubnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "${var.dcName}-vnic" {
  name                = "${var.dcName}-vnic"
  count               = var.numVMsToCreate
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.labsubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                  = var.dcName
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_F2"
  admin_username        = var.vmAdminUsername
  admin_password        = var.vmAdminPassword
  network_interface_ids = "${var.dcName}-vnic"

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

resource "azurerm_network_interface" "vnic" {
  name                = "${var.dcName}-vnic"
  count               = var.numVMsToCreate
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.labsubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                  = var.dcName
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_F2"
  admin_username        = var.vmAdminUsername
  admin_password        = var.vmAdminPassword
  network_interface_ids = "${var.dcName}-vnic"

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

# resource "azure_security_group" "labnsg" {
#   name     = "labservers"
#   location = azurerm_resource_group.rg.location
# }

# resource "azure_security_group_rule" "labnsg" {
#   name                       = "RDP"
#   security_group_names       = azure_security_group.labnsg.name
#   type                       = "Inbound"
#   action                     = "Allow"
#   priority                   = 200
#   source_address_prefix      = "*"
#   source_port_range          = "*"
#   destination_address_prefix = "*"
#   destination_port_range     = "3389"
#   protocol                   = "TCP"
# }

resource "azurerm_public_ip" "pubIp" {
  name                = "${var.labName}-pubIp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_subnet" "bastionsubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.3.0/24"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "labbastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "labbastionconfig"
    subnet_id            = azurerm_subnet.bastionsubnet.id
    public_ip_address_id = azurerm_public_ip.pubIp.id
  }
}
