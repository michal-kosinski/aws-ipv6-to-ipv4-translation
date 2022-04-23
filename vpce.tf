variable "vpc_endpoints" {
  type    = list(string)
  default = [
    "ecr.api",
    "ecr.dkr",
    "elasticloadbalancing",
    "logs",
    "sts"
  ]
}

resource "aws_vpc_endpoint" "eks" {
  for_each            = toset(var.vpc_endpoints)
  vpc_id              = aws_vpc.test.id
  subnet_ids          = [aws_subnet.internal_1.id, aws_subnet.internal_2.id]
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
}