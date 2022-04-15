resource "random_password" "rds" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "internal" {
  name       = "mikosins-test"
  subnet_ids = [aws_subnet.internal_1.id, aws_subnet.internal_2.id]
}

#resource "aws_db_subnet_group" "ipv6" {
#  name       = "mikosins-ipv6"
#  subnet_ids = [aws_subnet.ipv6.id, aws_subnet.ipv6_2.id]
#}

resource "aws_db_instance" "test" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.small"
  username               = "mikosins"
  password               = random_password.rds.result
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.internal.name
  vpc_security_group_ids = [aws_security_group.ipv6.id]
}