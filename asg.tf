resource "aws_launch_template" "test" {
  name_prefix            = var.common_name
  image_id               = data.aws_ami.ecs.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.test.key_name
  user_data              = base64encode(file("userdata6.sh"))
  vpc_security_group_ids = [aws_security_group.ipv6.id]
  iam_instance_profile {
    arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/ecsInstanceRole"
  }

  private_dns_name_options {
    enable_resource_name_dns_aaaa_record = true
    enable_resource_name_dns_a_record    = false
    hostname_type                        = "resource-name"
  }

  metadata_options {
    # This can be set only using launch templates, still not supported in the aws_instance resource
    # https://github.com/hashicorp/terraform-provider-aws/issues/22332
    http_protocol_ipv6 = "enabled"
  }

  instance_market_options {
    market_type = "spot"
  }
}

resource "aws_autoscaling_group" "test" {
  name_prefix         = var.common_name
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.ipv6_1.id, aws_subnet.ipv6_2.id]
  launch_template {
    id      = aws_launch_template.test.id
    version = aws_launch_template.test.latest_version
  }
}