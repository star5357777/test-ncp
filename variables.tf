# IAM Access Key
variable "access_key" {}
variable "secret_key" {}

# Assume role
variable "assume_role" {}

# VPC
variable "vpc" {
  type = object({
    cidr_block = string
    name       = string
  })
}

# Subnet
variable "subnet" {
  type = object({
    cidr_block = string
    az         = string
    name       = string
  })
}

# Security Group 
variable "security_group_name" {
  type = string
}

# EC2 List
variable "server" {
  type = map(object({
    server_name       = string
    os_disk_name      = string
    server_image_code = string
    server_spec_code  = string
    os_volume_type    = string
    os_volume_size    = number
    nics = list(object({
      private_ips     = list(string)
      nic_index = number
    }))
    kms_key_arn = string
  }))
}

# EBS List (attach to EC2)
variable "server_storage" {
  type = map(object({
    server_key   = string
    storage_name = string  
    device_name  = string
    data_volume_availability_zone = string
    storage_type = string
    storage_size = number
  }))
}

variable "force_detach" {
  type = bool
}

# CUNi Data
variable "project_code" {}
variable "csp_code" {}
variable "account_id" {
  type = string
  default = "0"
}
