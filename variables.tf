# Provider Access Key
variable "access_key" {
    type = string
}

variable "secret_key" {
    type = string
}

variable "region" {
    type = string
}

variable "site" {
    type = string
}

variable "support_vpc" {
    type = bool
}

# VPC Variable
variable "vpc_cidr" {
    type = string
}

variable "vpc_name" {
    type = string
}

# Network ACL Variable
variable "nacl_name" {
    type = string
}

# Subnet Variable
variable "subnet_cidr" {
    type = string
}

variable "zone" {
    type = string
}

variable "subnet_type" {
    type = string
}

variable "subnet_name" {
    type = string
}

variable "usage" {
    type = string
}

# Route Table Variable
variable "create_table" {
    type = bool
}

variable "route_table_name" {
    type = string
}

variable "route_table_subnet_type" {
    type = string
}

# Access Control Group Variable
variable "nacg_name" {
    type = string
} 

# Server Variable
variable "server" {
    type = map(object({
        server_name = string
        server_image_code = string
        server_product_code = string
        nics = list(object({
            private_ips = string
            order = number
        }))
    }))
}

# Storage Variable
variable "server_storage" {
    type = map(object({
        server_key = string
        storage_name = string
        storage_size = number
    }))
}
