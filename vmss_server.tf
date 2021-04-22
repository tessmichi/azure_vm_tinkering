# Create subnet
resource "azurerm_subnet" "subnet_server" {
  name                 = "subnet_server"
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_virtual_network.myterraformnetwork
  ]
}

#############################################
# Add a virtual machine scale set
#############################################

resource "azurerm_lb" "vmss" {
  name                = "vmss-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  frontend_ip_configuration {
    name                          = "FrontendIPAddressServer"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet_server.id
  }

  tags = var.tags

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_subnet.subnet_server
  ]
}
output "private_ip_lb_vmss" {
  value = azurerm_lb.vmss.private_ip_address
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  loadbalancer_id     = azurerm_lb.vmss.id
  name                = "BackEndAddressPool"

  depends_on = [
    azurerm_resource_group.myterraformgroup
  ]
}

resource "azurerm_lb_probe" "vmss" {
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  loadbalancer_id     = azurerm_lb.vmss.id
  name                = "ssh-running-probe"
  port                = var.application_port

  depends_on = [
    azurerm_resource_group.myterraformgroup
  ]
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.myterraformgroup.name
  loadbalancer_id                = azurerm_lb.vmss.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "FrontendIPAddressServer"
  probe_id                       = azurerm_lb_probe.vmss.id

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_lb.vmss,
    azurerm_lb_backend_address_pool.bpepool,
    azurerm_lb_probe.vmss
  ]
}

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "vmscaleset"
  location            = var.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = var.admin_user
    admin_password       = var.admin_password
    custom_data          = file("web.conf")
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.subnet_server.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      primary                                = true
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_subnet.subnet_server,
    azurerm_lb_backend_address_pool.bpepool
  ]
}


#########################################
# add an ssh jumpbox
#########################################

# Create network interface on the subnet
resource "azurerm_network_interface" "nic_server" {
  name                = "nic_server"
  location            = var.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                          = "nicconfig_server"
    subnet_id                     = azurerm_subnet.subnet_server.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = var.tags

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_subnet.subnet_server
  ]

  # Exported: applied_dns_servers, id, internal_domain_suffix, mac_address, [private_ip_address, private_ip_addresses], virtual_machine_id
}
output "private_ip_server" {
  value = azurerm_network_interface.nic_server.private_ip_addresses
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsg2nic_server" {
  network_interface_id      = azurerm_network_interface.nic_server.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  depends_on = [
    azurerm_network_interface.nic_server,
    azurerm_network_security_group.myterraformnsg
  ]
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage_server" {
  name                     = "sdiag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.myterraformgroup.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Terraform Demo"
  }

  depends_on = [
    azurerm_resource_group.myterraformgroup
  ]
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "vm_server" {
  name                  = "vm_server"
  location              = azurerm_network_interface.nic_server.location
  resource_group_name   = azurerm_resource_group.myterraformgroup.name
  network_interface_ids = [azurerm_network_interface.nic_server.id]
  size                  = "Standard_DS3_v2"

  os_disk {
    name                 = "myOsDiskServer"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "vmserver"
  admin_username = var.admin_user
  admin_password = var.admin_password

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_server.primary_blob_endpoint
  }

  tags = var.tags

  depends_on = [
    azurerm_resource_group.myterraformgroup,
    azurerm_network_interface.nic_server,
    azurerm_storage_account.storage_server
  ]
}
