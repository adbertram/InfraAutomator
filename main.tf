provider "azurerm" {
  version = "=2.5.0"
  features {}
}

variable "rgName" {
  type = string
}

variable "rgLocation" {
  type = string
}

variable "vmAdminUsername" {
  type = string
}

variable "vmAdminPassword" {
  type = string
}

variable "subnetId" {
  type = string
}

variable "vmName" {
  type = string
}

variable "vmSize" {
  type = string
}

variable "nsgId" {
  type = string
}

resource "azurerm_public_ip" "pip" {
  name                = "pip"
  resource_group_name = var.rgName
  location            = var.rgLocation
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "vnic" {
  name                = "vnic"
  location            = var.rgLocation
  resource_group_name = var.rgName

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnetId
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg-assoc" {
  network_interface_id      = azurerm_network_interface.vnic.id
  network_security_group_id = var.nsgId
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = var.vmName
  resource_group_name   = var.rgName
  location              = var.rgLocation
  size                  = var.vmSize
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

output "VM_IP" {
  value       = azurerm_public_ip.pip.ip_address
}