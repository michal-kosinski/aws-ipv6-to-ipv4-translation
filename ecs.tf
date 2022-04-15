resource "aws_ecs_cluster" "test" {
  count = var.create_ecs == true ? 1 : 0
  name  = var.common_name
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "test" {
  count              = var.create_ecs == true ? 1 : 0
  cluster_name       = aws_ecs_cluster.test[0].name
  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}

#resource "aws_ecs_service" "test" {
#  name            = "mikosins-test"
#  cluster         = aws_ecs_cluster.test.id
#  task_definition = aws_ecs_task_definition.test.arn
#  desired_count   = 1
#  launch_type     = "EC2"
#
#  load_balancer {
#    target_group_arn = data.aws_lb_target_group.test.arn
#    container_name   = "mikosins-test"
#    container_port   = 80
#  }
#
#  network_configuration {
#    subnets         = [aws_subnet.ipv6.id]
#    security_groups = [aws_security_group.ipv6.id]
#    #    assign_public_ip = false
#  }
#}

resource "aws_ecs_task_definition" "test" {
  count                    = var.create_ecs == true ? 1 : 0
  family                   = var.common_name
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"

  # IPv6 registry must be used: https://www.docker.com/blog/beta-ipv6-support-on-docker-hub-registry/
  container_definitions = jsonencode([
    {
      name         = var.common_name
      image        = "registry.ipv6.docker.com/library/nginx:latest"
      cpu          = 256
      memory       = 512
      essential    = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    },
  ])
}