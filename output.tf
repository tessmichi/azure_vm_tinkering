output "vmss_public_ip" {
    value = azurerm_public_ip.vmss.fqdn
}
# vmss_public_ip = "aqlbej.westus.cloudapp.azure.com"


output "jumpbox_public_ip" {
   value = azurerm_public_ip.jumpbox.fqdn
}