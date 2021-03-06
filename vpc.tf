resource "aws_vpc" "test" {
  cidr_block                       = "10.254.0.0/16"
  instance_tenancy                 = "default"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${var.common_name}-dualstack"
  }
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id
}

resource "aws_egress_only_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id
}

resource "aws_subnet" "external" {
  vpc_id                                         = aws_vpc.test.id
  availability_zone                              = data.aws_availability_zones.available.names[0]
  cidr_block                                     = cidrsubnet(aws_vpc.test.cidr_block, 8, 1)
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.test.ipv6_cidr_block, 8, 1)
  enable_dns64                                   = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_resource_name_dns_a_record_on_launch    = false
  ipv6_native                                    = false
  assign_ipv6_address_on_creation                = true
  private_dns_hostname_type_on_launch            = "resource-name"

  tags = {
    Name = "${var.common_name}-external"
  }
}

resource "aws_subnet" "internal_1" {
  vpc_id                                         = aws_vpc.test.id
  availability_zone                              = data.aws_availability_zones.available.names[0]
  cidr_block                                     = cidrsubnet(aws_vpc.test.cidr_block, 8, 2)
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.test.ipv6_cidr_block, 8, 2)
  enable_dns64                                   = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_resource_name_dns_a_record_on_launch    = false
  ipv6_native                                    = false
  assign_ipv6_address_on_creation                = true
  private_dns_hostname_type_on_launch            = "resource-name"

  tags = {
    Name                                       = "${var.common_name}-internal-1"
    "kubernetes.io/cluster/${var.common_name}" = "shared"
  }
}

resource "aws_subnet" "internal_2" {
  vpc_id                                         = aws_vpc.test.id
  availability_zone                              = data.aws_availability_zones.available.names[1]
  cidr_block                                     = cidrsubnet(aws_vpc.test.cidr_block, 8, 3)
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.test.ipv6_cidr_block, 8, 3)
  enable_dns64                                   = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_resource_name_dns_a_record_on_launch    = false
  ipv6_native                                    = false
  assign_ipv6_address_on_creation                = true
  private_dns_hostname_type_on_launch            = "resource-name"

  tags = {
    Name                                       = "${var.common_name}-internal-2"
    "kubernetes.io/cluster/${var.common_name}" = "shared"
  }
}

resource "aws_eip" "natgw" {
  vpc        = true
  depends_on = [aws_internet_gateway.test]
}

resource "aws_nat_gateway" "test" {
  connectivity_type = "public"
  subnet_id         = aws_subnet.external.id
  allocation_id     = aws_eip.natgw.allocation_id
}

resource "aws_subnet" "ipv6_1" {
  vpc_id                                         = aws_vpc.test.id
  availability_zone                              = data.aws_availability_zones.available.names[0]
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.test.ipv6_cidr_block, 8, 4)
  enable_dns64                                   = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_resource_name_dns_a_record_on_launch    = false
  ipv6_native                                    = true
  assign_ipv6_address_on_creation                = true
  private_dns_hostname_type_on_launch            = "resource-name"

  tags = {
    Name                                       = "${var.common_name}-ipv6-1"
    "kubernetes.io/cluster/${var.common_name}" = "shared"
  }
}

resource "aws_subnet" "ipv6_2" {
  vpc_id                                         = aws_vpc.test.id
  availability_zone                              = data.aws_availability_zones.available.names[1]
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.test.ipv6_cidr_block, 8, 5)
  enable_dns64                                   = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  enable_resource_name_dns_a_record_on_launch    = false
  ipv6_native                                    = true
  assign_ipv6_address_on_creation                = true
  private_dns_hostname_type_on_launch            = "resource-name"

  tags = {
    Name                                       = "${var.common_name}-ipv6-2"
    "kubernetes.io/cluster/${var.common_name}" = "shared"
  }
}

resource "aws_route_table" "external" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = {
    Name = "${var.common_name}-external"
  }
}

resource "aws_route_table" "internal" {
  vpc_id = aws_vpc.test.id

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_egress_only_internet_gateway.test.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.test.id
  }

  tags = {
    Name = "${var.common_name}-internal"
  }
}

resource "aws_route_table" "ipv6" {
  vpc_id = aws_vpc.test.id

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_egress_only_internet_gateway.test.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96" # well-known prefix for IPv6 to IPv4 translation (RFC 6052)
    nat_gateway_id  = aws_nat_gateway.test.id
  }

  tags = {
    Name = "${var.common_name}-ipv6"
  }
}

resource "aws_route_table_association" "external" {
  subnet_id      = aws_subnet.external.id
  route_table_id = aws_route_table.external.id
}

resource "aws_route_table_association" "internal_1" {
  subnet_id      = aws_subnet.internal_1.id
  route_table_id = aws_route_table.internal.id
}

resource "aws_route_table_association" "internal_2" {
  subnet_id      = aws_subnet.internal_2.id
  route_table_id = aws_route_table.internal.id
}


resource "aws_route_table_association" "ipv6_1" {
  subnet_id      = aws_subnet.ipv6_1.id
  route_table_id = aws_route_table.ipv6.id
}

resource "aws_route_table_association" "ipv6_2" {
  subnet_id      = aws_subnet.ipv6_2.id
  route_table_id = aws_route_table.ipv6.id
}