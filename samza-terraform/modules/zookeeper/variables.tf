variable "prefix" {
  description = "The prefix used for all resources in this example"
}

variable "zk-prefix" {
  default     = "zookeeper"
  description = "The prefix used for all resources used by Zookeeper"
}

variable "location" {
  description = "The Azure location where all resources in this example should be created"
}

variable "resource_group_name" {
  description = "The name of the resouce group"
}

variable "zookeeper_subnet" {
  description = "The name of the subnet the Zookeeper node belongs to"
}

variable "zookeeper_vnet" {
  description = "The name of the vnet the Zookeeper node belongs to"
}

variable "zookeeper_nsg" {
  description = "The name of the network security group the Zookeeper instance belongs"
}

variable "username" {
  description = "The username used to login to the machine"
}
variable "password" {
  description = "The password used to login to the machine"
}

variable "vm_size" {
  description = "The VM SKU"
}

variable "storage_image_publisher" {
  description = "Image publisher"
}

variable "storage_image_offer" {
  description = "Image offer"
}

variable "storage_image_sku" {
  description = "Image SKU"
}

variable "storage_image_version" {
  description = "Image Version"
}