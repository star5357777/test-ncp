# VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc.cidr_block
  tags = {
    Name = var.vpc.name
  }
}

# Subnet
resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet.cidr_block
  availability_zone = var.subnet.az
  tags = {
    Name = var.subnet.name
  }
}

# Security Group
resource "aws_security_group" "security_group" {
  name        = var.security_group_name
  vpc_id      = aws_vpc.vpc.id

  # 모든 인바운드 트래픽 허용
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-allow-any"
  }
}

# Local Variable
locals { 
  # Extract NICs information for each server
  nics_info = { for idx, ni in flatten([
                for srv_name, srv in var.server : [
                  for nic_idx, nic in srv.nics : {
                    server_key         = srv_name
                    nic_index          = nic.nic_index
                    subnet_id          = aws_subnet.subnet.id
                    private_ips        = nic.private_ips
                    security_group_ids = [aws_security_group.security_group.id]
                  }
                ]
              ]) : "${ni.server_key}-${ni.nic_index}" => ni }

  # For additional NICs - Exclude variables with index 0(*root NIC)
  excluding_nic_idx0 = { for k,v in local.nics_info : k => v if v.nic_index != 0 }

  # Attach data-disks only if instances exist
  filtered_server_storage = { for k, v in var.server_storage : k => v 
                              if contains(keys(aws_instance.instance), v.server_key) }
}

# Network Interface
resource "aws_network_interface" "network_interface" {  
  for_each        = local.nics_info 
  subnet_id       = each.value.subnet_id
  private_ips     = each.value.private_ips
  security_groups = each.value.security_group_ids

  tags = {
    Name = "${each.value.server_key}-nic-${each.value.nic_index}"
  }
}

resource "aws_network_interface_attachment" "additional_nic_attachment" {
  for_each             = local.excluding_nic_idx0
  instance_id          = aws_instance.instance[each.value.server_key].id
  network_interface_id = aws_network_interface.network_interface["${each.value.server_key}-${each.value.nic_index}"].id
  device_index         = each.value.nic_index
}

# EC2 Instance
resource "aws_instance" "instance" {
  for_each      = var.server
  ami           = each.value.server_image_code
  instance_type = each.value.server_spec_code
  
  tags = {
     Name = each.value.server_name
  }

  network_interface {   
    network_interface_id = aws_network_interface.network_interface["${each.key}-0"].id //*changed on 240131 -req4 : NIC 여러 개 부착하는 경우
    device_index         = 0
  }

  root_block_device {
    volume_type = each.value.os_volume_type
    volume_size = each.value.os_volume_size
    tags = {
      Name = each.value.os_disk_name
    }
    encrypted  = "true"
    kms_key_id = each.value.kms_key_arn
    delete_on_termination = false
  }

  metadata_options {            
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  depends_on = [aws_network_interface.network_interface]
}

# EBS Volume
resource "aws_ebs_volume" "data_disk" {
  for_each          = var.server_storage
  availability_zone = each.value.data_volume_availability_zone
  type = each.value.storage_type
  size = each.value.storage_size
  tags = {
      Name = each.value.storage_name
  }
}

resource "aws_volume_attachment" "data_disk_attachment" {
  for_each      = local.filtered_server_storage
  force_detach  = var.force_detach
  device_name   = each.value.device_name
  volume_id     = aws_ebs_volume.data_disk[each.key].id
  instance_id   = aws_instance.instance[each.value.server_key].id
}