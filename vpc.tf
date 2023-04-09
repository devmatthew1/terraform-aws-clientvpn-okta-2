resource "aws_vpc" "main" {
  cidr_block = "172.20.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"
  tags = local.global_tags

}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.global_tags
}

resource "aws_subnet" "sn_az" {
  count = length(local.availability_zones)

  availability_zone = local.availability_zones[count.index]

  vpc_id = aws_vpc.main.id
  map_public_ip_on_launch = false

  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 5, count.index+1)

  
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

 
}

resource "aws_route_table_association" "rt_assoc" {
  count = length(aws_subnet.sn_az)

  route_table_id = aws_route_table.rt.id
  subnet_id = aws_subnet.sn_az[count.index].id
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  region = "us-east-2"
  global_tags = {
    "environment" = "vpn-example"
  }
  availability_zones = sort(data.aws_availability_zones.available.names)
}
