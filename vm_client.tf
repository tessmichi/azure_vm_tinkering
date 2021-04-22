# Create subnet
resource "azurerm_subnet" "subnet_client" {
  name                 = "subnet_client"
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.2.0/24"]

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_virtual_network.myterraformnetwork
  ]
}

# Create network interface on the subnet
resource "azurerm_network_interface" "nic_client" {
  name                = "nic_client"
  location                 = var.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                          = "nicconfig_client"
    subnet_id                     = azurerm_subnet.subnet_client.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = var.tags

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_subnet.subnet_client
  ]

  # Exported: applied_dns_servers, id, internal_domain_suffix, mac_address, [private_ip_address, private_ip_addresses], virtual_machine_id
}
output "private_ip_client" {
  value = azurerm_network_interface.nic_client.private_ip_addresses
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsg2nic_client" {
  network_interface_id      = azurerm_network_interface.nic_client.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  depends_on = [
    azurerm_network_interface.nic_client,
    azurerm_network_security_group.myterraformnsg
  ]
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage_client" {
  name                     = "cdiag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.myterraformgroup.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags

  depends_on = [
    azurerm_resource_group.myterraformgroup
  ]
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "vm_client" {
  name                  = "vm_client"
  location              = azurerm_network_interface.nic_client.location
  resource_group_name   = azurerm_resource_group.myterraformgroup.name
  network_interface_ids = [azurerm_network_interface.nic_client.id]
  size                  = "Standard_DS3_v2"

  os_disk {
    name                 = "myOsDiskClient"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "vmclient"
  admin_username = var.admin_user
  admin_password = var.admin_password

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_client.primary_blob_endpoint
  }

  tags = var.tags

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_network_interface.nic_client,
    azurerm_storage_account.storage_client
  ]
}
