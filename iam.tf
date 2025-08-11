################################################################################
# EKS control-plane IAM role (unchanged)
################################################################################
data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

################################################################################
# Read EKS cluster info (OIDC issuer)
# Add depends_on = [module.eks] if the cluster is created in the same apply via a module
################################################################################
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
  # depends_on = [module.eks]   # uncomment if your EKS is created in the same apply via module "eks"
}

################################################################################
# Reference the existing IAM OIDC provider for the EKS cluster
# (We use data to avoid "Provider already exists" errors)
################################################################################
data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  # depends_on = [data.aws_eks_cluster.cluster]   # optional
}

################################################################################
# ALB controller IAM role (IRSA trust)
################################################################################
resource "aws_iam_role" "alb_controller" {
  name = "alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        # Use the data source (existing OIDC provider)
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          # must remove https:// for the key, keep full issuer for the value
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  # Ensure cluster and OIDC provider exist (uncomment if necessary)
  # depends_on = [module.eks, data.aws_iam_openid_connect_provider.eks]
}

################################################################################
# Inline ALB Controller IAM policy (full policy in Terraform)
# This avoids the need for iam_policy.json external file.
################################################################################
resource "aws_iam_policy" "alb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller (created inline)"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "acm:DescribeCertificate",
        "acm:ListCertificates",
        "acm:GetCertificate",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:Describe*",
        "elasticloadbalancing:*",
        "iam:CreateServiceLinkedRole",
        "iam:GetServerCertificate",
        "iam:ListServerCertificates",
        "cognito-idp:DescribeUserPoolClient",
        "waf-regional:GetWebACLForResource",
        "waf-regional:GetWebACL",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:GetWebACL",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection",
        "tag:GetResources",
        "tag:TagResources",
        "tag:UntagResources"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

################################################################################
# Attach the policy to the ALB controller role
################################################################################
resource "aws_iam_policy_attachment" "alb_controller_policy_attach" {
  name       = "alb-controller-policy-attachment"
  roles      = [aws_iam_role.alb_controller.name]
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}
