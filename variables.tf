variable "location" {
  type        = string
  description = "An Azure region that supports all object types that will use this variable as its region"
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use for the resources that are deployed"
}

variable "resource_group_name" {
  type        = string
  description = "The VM tinkering resource by Tess/Jeff"
}

variable "admin_user" {
  type        = string
  description = "User name to use as the admin account on the VMs that will be part of the VM Scale Set"
}

variable "admin_password" {
  type        = string
  description = "Default password for admin account"
}
