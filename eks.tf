resource "aws_eks_cluster" "test" {
  count    = var.create_eks == true ? 1 : 0
  name     = "mikosins-test"
  role_arn = aws_iam_role.eks[0].arn

  vpc_config {
    subnet_ids              = [aws_subnet.internal_1.id, aws_subnet.internal_2.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  kubernetes_network_config {
    ip_family = "ipv6"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = var.create_eks ? aws_eks_cluster.test[0].endpoint : null
}

output "kubeconfig-certificate-authority-data" {
  value = var.create_eks ? aws_eks_cluster.test[0].certificate_authority[0].data : null
}

resource "aws_eks_fargate_profile" "test" {
  count                  = var.create_eks == true ? 1 : 0
  cluster_name           = aws_eks_cluster.test[0].name
  fargate_profile_name   = var.common_name
  pod_execution_role_arn = aws_iam_role.eks_fargate[0].arn
  subnet_ids             = [aws_subnet.internal_1.id, aws_subnet.internal_2.id]

  selector {
    namespace = "eks-sample-app"
  }
}

resource "aws_eks_node_group" "test" {
  count           = var.create_eks == true ? 1 : 0
  cluster_name    = aws_eks_cluster.test[0].name
  node_group_name = var.common_name
  node_role_arn   = aws_iam_role.eks_node_group[0].arn
  subnet_ids      = [aws_subnet.internal_1.id, aws_subnet.internal_2.id]

  remote_access {
    ec2_ssh_key = aws_key_pair.test.key_name
  }

  instance_types = [var.instance_type]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}