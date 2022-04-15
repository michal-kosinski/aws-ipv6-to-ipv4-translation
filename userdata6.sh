#!/usr/bin/env bash
echo ECS_CLUSTER=mikosins-test >> /etc/ecs/ecs.config
echo ECS_BACKEND_HOST= >> /etc/ecs/ecs.config
# If you launched an EC2 instance that uses an Amazon Linux 2 AMI into an IPv6-only subnet, you must connect to the instance and run sudo amazon-linux-https disable. This lets your AL2 instance connect to the yum repository in S3 over IPv6 using the http patch service.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-updates.html
amazon-linux-https disable
yum install -y telnet
yum install -y bind-utils
yum install -y httpd
systemctl start httpd.service
systemctl enable httpd.service
echo "Hello World from $(hostname -I)" > /var/www/html/index.html
