resource "aws_lb" "dualstack" {
  name               = "ipv6-test"
  internal           = false
  ip_address_type    = "dualstack"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dualstack_lb.id]
  subnets            = [aws_subnet.internal_1.id, aws_subnet.internal_2.id]

  provisioner "local-exec" {
    command = "python3 ${path.cwd}/tg.py create"

    environment = {
      AWS_REGION = data.aws_region.current.name
      VPC_ID     = aws_vpc.test.id
      ALB_ARN    = self.arn
      ALB_NAME   = self.name
      ASG_NANE   = aws_autoscaling_group.test.name
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "python3 ${path.cwd}/tg.py destroy"

    environment = {
      ALB_NAME   = self.name
      # Destroy-time provisioners and their connection configurations may only reference attributes of the relate resourceDestroy-time provisioners and their connection configurations may only reference attributes of the relate resource, via 'self', 'count.index', or 'each.key'.
      AWS_REGION = "eu-west-1"
    }
  }
}

resource "aws_lb_listener" "dualstack" {
  load_balancer_arn = aws_lb.dualstack.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.test.arn
  }
}

resource "null_resource" "tg" {
  triggers = {
    latest_version = aws_launch_template.test.latest_version
  }

  provisioner "local-exec" {
    command = "python3 ${path.cwd}/tg.py update"

    environment = {
      AWS_REGION = data.aws_region.current.name
      ASG_NANE   = aws_autoscaling_group.test.name
      TG_ARN     = data.aws_lb_target_group.test.arn
    }
  }
}

resource "aws_security_group" "dualstack_lb" {
  name   = "${var.common_name}-lb"
  vpc_id = aws_vpc.test.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
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