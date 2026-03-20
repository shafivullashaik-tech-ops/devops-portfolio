# IAM Module - IRSA Roles for EKS Service Accounts
# Creates IAM roles for various EKS services using IRSA

data "aws_partition" "current" {}

################################################################################
# EBS CSI Driver IRSA
################################################################################

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.create_ebs_csi_driver_role ? 1 : 0
  name  = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count      = var.create_ebs_csi_driver_role ? 1 : 0
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}

################################################################################
# ArgoCD IRSA (optional)
################################################################################

resource "aws_iam_role" "argocd" {
  count = var.create_argocd_role ? 1 : 0
  name  = "${var.cluster_name}-argocd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.argocd_namespace}:argocd-application-controller"
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

################################################################################
# Jenkins IRSA — allows Jenkins (on EKS) to push to ECR and describe EKS
################################################################################

resource "aws_iam_role" "jenkins_irsa" {
  count = var.create_jenkins_role ? 1 : 0
  name  = "${var.cluster_name}-jenkins-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.jenkins_namespace}:jenkins"
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "jenkins_ecr" {
  count = var.create_jenkins_role ? 1 : 0
  name  = "${var.cluster_name}-jenkins-ecr-policy"
  role  = aws_iam_role.jenkins_irsa[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        # GetAuthorizationToken is a global action — must be *
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        # Allow push/pull to ALL ECR repos passed in via variable
        Resource = var.jenkins_ecr_repository_arns
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = var.eks_cluster_arn
      },
    ]
  })
}

################################################################################
# LLM Gateway IRSA — allows llm-gateway pod to access AWS Secrets Manager
################################################################################

resource "aws_iam_role" "llm_gateway_irsa" {
  count = var.create_llm_gateway_role ? 1 : 0
  name  = "${var.cluster_name}-llm-gateway-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:llmops:llm-gateway"
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "llm_gateway_secrets" {
  count = var.create_llm_gateway_role ? 1 : 0
  name  = "${var.cluster_name}-llm-gateway-secrets-policy"
  role  = aws_iam_role.llm_gateway_irsa[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:llm-gateway/*"
      },
    ]
  })
}
