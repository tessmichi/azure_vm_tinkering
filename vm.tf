# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westus2"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "Terraform Demo"
    }

    depends_on = [
      azurerm_resource_group.myterraformgroup
    ]
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]

    depends_on = [
      azurerm_resource_group.myterraformgroup,
      azurerm_virtual_network.myterraformnetwork
    ]
}

# Create public IPs
#resource "azurerm_public_ip" "myterraformpublicip" {
#    name                         = "myPublicIP"
#    location                     = "westus2"
#    resource_group_name          = azurerm_resource_group.myterraformgroup.name
#    allocation_method            = "Dynamic"

#    tags = {
#        environment = "Terraform Demo"
#    }
#}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "westus2"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }

    depends_on = [
      azurerm_resource_group.myterraformgroup
    ]
}

# Create network interface on the subnet
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = "westus2" # must be same as VM
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        #public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }

    depends_on = [
      azurerm_resource_group.myterraformgroup,
      azurerm_subnet.myterraformsubnet
    ]

    # Exported: applied_dns_servers, id, internal_domain_suffix, mac_address, [private_ip_address, private_ip_addresses], virtual_machine_id
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id

    depends_on = [
      azurerm_network_interface.myterraformnic,
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
resource "azurerm_storage_account" "mystorageaccount" {
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

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" {
    value = tls_private_key.example_ssh.private_key_pem
    sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = "westus2"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "myvm"
    admin_username = "azureuser"
    admin_password = var.ADMIN_PASSWORD
    disable_password_authentication = false

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
    
    depends_on = [
      azurerm_resource_group.myterraformgroup,
      azurerm_network_interface.myterraformnic,
      tls_private_key.example_ssh,
      azurerm_storage_account.mystorageaccount
    ]
}