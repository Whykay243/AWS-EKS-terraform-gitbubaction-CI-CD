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

# Fetch EKS cluster info for OIDC URL
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Reference existing OIDC provider for the EKS cluster
data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# Create IAM Role for AWS Load Balancer Controller with trust policy to OIDC provider
resource "aws_iam_role" "alb_controller" {
  name = "alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        # Use data source since OIDC provider already exists
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# Create the ALB Controller IAM policy from local file (you need to add iam_policy.json file in your module)
resource "aws_iam_policy" "alb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy = file("iam_policy.json")
 #policy      = file("${path.module}/iam_policy.json")
}

# Attach the ALB Controller IAM policy created above to the role
resource "aws_iam_policy_attachment" "alb_controller_policy_attach" {
  name       = "alb-controller-policy-attachment"
  roles      = [aws_iam_role.alb_controller.name]
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}
