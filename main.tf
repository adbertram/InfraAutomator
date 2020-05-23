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

variable "vmCount" {
  type = number
}

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
  name                = "pubIp${count.index}"
  count               = var.vmCount
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "vnic" {
  name                = "vnic${count.index}"
  count               = var.vmCount
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = "${length(azurerm_public_ip.pubIp.*.id) > 0 ? element(concat(azurerm_public_ip.pubIp.*.id, list("")), count.index) : ""}"
    # public_ip_address_id = [element(azurerm_public_ip.pubIp.*.id, count.index)]
    public_ip_address_id = azurerm_public_ip.pubIp[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg-assoc" {
  count                     = var.vmCount
  network_interface_id      = element(azurerm_network_interface.vnic.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "vm-${count.index}"
  count                 = var.vmCount
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_F2"
  admin_username        = var.vmAdminUsername
  admin_password        = var.vmAdminPassword
  network_interface_ids = [element(azurerm_network_interface.vnic.*.id, count.index)]

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

resource "azurerm_network_security_group" "nsg" {
  name                = "rdp-access"
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
}

# output "pubips" {
#   value       = azurerm_public_ip.pubIp.ip_address
#   description = "Public IPs of the VMs"
# }
