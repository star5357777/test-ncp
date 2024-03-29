# Local Variable
locals { 
  # Extract NICs information for each server
  nics_info = { for idx, ni in flatten([
                for srv_name, srv in var.server : [
                  for nic_idx, nic in srv.nics : {
                    server_key         = srv_name
                    nic_index          = nic.order
                    subnet_id          = ncloud_subnet.subnet.id
                    private_ips        = nic.private_ips
                    security_group_ids = [ncloud_access_control_group.nacg.id]
                  }
                ]
              ]) : "${ni.server_key}-${ni.nic_index}" => ni }

  # For additional NICs - Exclude variables with index 0(*root NIC)
  excluding_nic_idx0 = { for k,v in local.nics_info : k => v if v.nic_index != 0 }

    filtered_server_storage = { for k, v in var.server_storage : k => v 
                              if contains(keys(ncloud_server.server), v.server_key) }
}
# Create VPC
resource "ncloud_vpc" "vpc" {
    ipv4_cidr_block = var.vpc_cidr
    name = var.vpc_name
}

# Create Nacl
resource "ncloud_network_acl" "nacl" {
    vpc_no = ncloud_vpc.vpc.id
    name = var.nacl_name
}

# Nacl Allow All
resource "ncloud_network_acl_rule" "nacl_rule" {
    network_acl_no = ncloud_network_acl.nacl.id
    inbound {
        priority = 100
        protocol = "TCP"
        rule_action = "ALLOW"
        ip_block = "0.0.0.0/0"
        port_range = "1-65535"
    }
    outbound {
        priority = 100
        protocol = "TCP"
        rule_action = "ALLOW"
        ip_block = "0.0.0.0/0"
        port_range = "1-65535"
    }
}

# Create Subnet
resource "ncloud_subnet" "subnet" {
    vpc_no = ncloud_vpc.vpc.id
    subnet = var.subnet_cidr
    zone = var.zone
    network_acl_no = ncloud_network_acl.nacl.id
    subnet_type = var.subnet_type
    name = var.subnet_name
    usage_type = var.usage
}

# Create Route Table
resource "ncloud_route_table" "route_table" {
    count = var.create_table ? 1 : 0
    vpc_no = ncloud_vpc.vpc.id
    name = var.create_table ? var.route_table_name : null
    supported_subnet_type = var.create_table ? var.route_table_subnet_type : null
}

# Route Table Association
resource "ncloud_route_table_association" "route_association" {
    count = length(ncloud_route_table.route_table[*].id) > 0 ? 1 : 0
    subnet_no = ncloud_subnet.subnet.id
    route_table_no = ncloud_route_table.route_table[count.index].id
}

# Create Access Control Group
resource "ncloud_access_control_group" "nacg" {
    name = var.nacg_name
    vpc_no = ncloud_vpc.vpc.id
}

# Define Access Control Group Rule
resource "ncloud_access_control_group_rule" "nacg_rule" {
    access_control_group_no = ncloud_access_control_group.nacg.id

    inbound {
        protocol = "TCP"
        ip_block = "0.0.0.0/0"
        port_range = "1-65535"
    }
    outbound {
        protocol = "TCP"
        ip_block = "0.0.0.0/0"
        port_range = "1-65535"
    }
}

# Create Network Interface
resource "ncloud_network_interface" "nic" {
    for_each = local.nics_info
    subnet_no = each.value.subnet_id
    private_ip = each.value.private_ips
    access_control_groups = each.value.security_group_ids
    name = "${each.value.server_key}-nic-${each.value.nic_index}"
}

# Create Server
resource "ncloud_server" "server" {
    for_each = var.server
    subnet_no = ncloud_subnet.subnet.id
    server_image_product_code = each.value.server_image_code
    server_product_code = each.value.server_product_code
    login_key_name = "ncp-test"

    dynamic "network_interface" {
        for_each = each.value.nics
        content {
            network_interface_no = ncloud_network_interface.nic["${each.key}-${network_interface.key}"].id
            order                = network_interface.value.order
        }
    }
    name = each.value.server_name

}

 # Create Block Storage
resource "ncloud_block_storage" "storage" {
    for_each = local.filtered_server_storage
    server_instance_no = ncloud_server.server[each.value.server_key].id
    name = each.value.storage_name
    size = each.value.storage_size
}