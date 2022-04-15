resource "aws_eip" "jumphost" {
  count      = var.create_jumphost == true ? 1 : 0
  instance   = aws_instance.jumphost[0].id
  vpc        = true
  depends_on = [aws_internet_gateway.test]
}

resource "aws_instance" "jumphost" {
  count              = var.create_jumphost == true ? 1 : 0
  ami                = data.aws_ami.amzn2.id
  instance_type      = var.instance_type
  subnet_id          = aws_subnet.external.id
  ipv6_address_count = 1
  security_groups    = [aws_security_group.jumphost.id]
  key_name           = aws_key_pair.test.key_name
  user_data          = file("userdata.sh")

  tags = {
    Name = "${var.common_name}-jumphost"
  }
}


resource "aws_security_group" "jumphost" {
  name   = "${var.common_name}-jumphost"
  vpc_id = aws_vpc.test.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.test.cidr_block]
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = [aws_vpc.test.ipv6_cidr_block]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "ipv6" {
  name   = "${var.common_name}-ipv6"
  vpc_id = aws_vpc.test.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.test.cidr_block]
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = [aws_vpc.test.ipv6_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }
}
