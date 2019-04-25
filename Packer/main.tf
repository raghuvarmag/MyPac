# Configure the provider
provider "azurerm" {
    version = "=1.20.0"
  subscription_id = "4027ce90-56f7-474c-a0fd-2ad77225d74c"
  client_id       = "142e2013-94ac-4e99-bab1-c5581a7fb6da"
  client_secret   = "a528117d-917c-493b-b5ce-1a256a8e2418"
  tenant_id       = "65a7c826-a96e-4d7c-a211-7030f2275399"

}

# Locate the existing custom/golden image
data "azurerm_image" "search" {
  name                = "app10SImage-201904250724"
  resource_group_name = "RaghuTFResourceGroup1"
}

output "image_id" {
  value = "/subscriptions/4027ce90-56f7-474c-a0fd-2ad77225d74c/resourceGroups/RaghuTFResourceGroup1/providers/Microsoft.Compute/images/app10SImage-201904250724"
}


# Create a Resource Group for the new Virtual Machine.
resource "azurerm_resource_group" "main" {
  name     = "RaghuTFResourceGroupAzureDevops"
  location = "West Europe"
}
# Create virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "RG-Terraform-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "West Europe"
    resource_group_name = "${azurerm_resource_group.main.name}"
}

# Create a Subnet within the Virtual Network
resource "azurerm_subnet" "internal" {
  name                 = "RG-Terraform-snet-in"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  address_prefix       = "10.0.1.0/24"
}

# Create a Network Security Group with some rules
resource "azurerm_network_security_group" "main" {
  name                = "RG-QA-Test-Dev-NSG"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  security_rule {
    name                       = "allow_rdp"
    description                = "Allow rdp access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4844"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create a network interface for VMs and attach the PIP and the NSG
resource "azurerm_network_interface" "main" {
  name                      = "NIC"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.main.id}"

  ip_configuration {
    name                          = "nicconfig"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "${cidrhost("10.0.1.0/24", 4)}"
  }
}

# Create a new Virtual Machine based on the Golden Image
resource "azurerm_virtual_machine" "vm" {
  name                             = "RAGPACVM"
  location                         = "${azurerm_resource_group.main.location}"
  resource_group_name              = "${azurerm_resource_group.main.name}"
  network_interface_ids            = ["${azurerm_network_interface.main.id}"]
  vm_size                          = "Standard_A2"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.search.id}"
  }

  storage_os_disk {
    name              = "RAGPACVM-OS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
}

  os_profile {
    computer_name  = "APPVM"
    admin_username = "devopsadmin"
    admin_password = "Cssladmin#2019"
  }
  os_profile_windows_config
  {
	enable_automatic_upgrades = false
    provision_vm_agent = true
  }
}
