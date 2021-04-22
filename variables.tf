variable "location" {
  type        = string
  description = "An Azure region that supports all object types that will use this variable as its region"
  default     = "westus2"
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use for the resources that are deployed"
  default = {
    environment = "dev"
  }
}

variable "resource_group_name" {
  type        = string
  description = "The VM tinkering resource by Tess/Jeff"
  default     = "vm-test-boa-dev-combined"
}

variable "application_port" {
  description = "The port that you want to expose to the external load balancer"
  default     = 80
}

variable "admin_user" {
  type        = string
  description = "User name to use as the admin account on the VMs that will be part of the VM Scale Set"
  default     = "azureuser"
}

variable "admin_password" {
  type        = string
  description = "Default password for admin account"
}
