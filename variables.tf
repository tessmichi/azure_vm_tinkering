variable "location" {
 description = "westus"
 default = "westus"
}

variable "tags" {
 description = "A map of the tags to use for the resources that are deployed"
 type        = map(string)

 default = {
   environment = "dev"
 }
}

variable "resource_group_name" {
 description = "The VM tinkering resource by Tess/Jeff"
 default     = "rg-tj-vm"
}

variable "application_port" {
   description = "The port that you want to expose to the external load balancer"
   default     = 80
}

variable "admin_user" {
   description = "User name to use as the admin account on the VMs that will be part of the VM Scale Set"
   default     = "azureuser"
}

variable "admin_password" {
   description = "Default password for admin account"
}