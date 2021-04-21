# Create subnet
resource "azurerm_subnet" "subnet_server" {
    name                 = "subnet_server"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]

    depends_on = [
      azurerm_resource_group.myterraformgroup,
      azurerm_virtual_network.myterraformnetwork
    ]
}

# Create network interface on the subnet
resource "azurerm_network_interface" "nic_server" {
    name                      = "nic_server"
    location                  = "westus2" # must be same as VM
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "nicconfig_server"
        subnet_id                     = azurerm_subnet.subnet_server.id
        private_ip_address_allocation = "Static"
        #public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }

    depends_on = [
      azurerm_resource_group.myterraformgroup,
      azurerm_subnet.subnet_server
    ]

    # Exported: applied_dns_servers, id, internal_domain_suffix, mac_address, [private_ip_address, private_ip_addresses], virtual_machine_id
}
output "private_ip" {
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

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
    
    depends_on = [
      azurerm_resource_group.myterraformgroup
    ]
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage_server" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "westus2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

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
    location              = "westus2"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.nic_server.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDiskServer"
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2016-Datacenter"
        version   = "latest"
    }

    computer_name  = "vmserver"
    admin_username = "azureuser"
    admin_password = var.ADMIN_PASSWORD

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storage_server.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
    
    depends_on = [
      azurerm_resource_group.myterraformgroup,
      azurerm_network_interface.nic_server,
      azurerm_storage_account.storage_server
    ]
}