# Call VPC module to create VPC with private and public subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  # Using 3 AZs for high availability
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  
  # 3 private subnets, one per AZ
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  
  # 3 public subnets, one per AZ
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true         # Enable NAT Gateway for private subnet internet access
  single_nat_gateway = true         # Use a single NAT Gateway

  enable_dns_hostnames = true       # Enable DNS hostnames for instances in the VPC
  enable_dns_support   = true       # Enable DNS resolution support in the VPC

  # Kubernetes tags for ELB integration — important for correct load balancer placement
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"            = "1"
  }
}

# Call EKS module to create the cluster and managed node groups
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.33"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  enable_irsa = true                # Enable IAM Roles for Service Accounts (IRSA)

  eks_managed_node_groups = {
    worker-nodes = {
      instance_types   = [var.node_instance_type]
      desired_capacity = var.desired_capacity
      max_capacity     = var.max_capacity
      min_capacity     = var.min_capacity
      key_name         = var.key_pair_name
    }
  }
}

# Get EKS cluster information after module creation
data "aws_eks_cluster" "app-cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Get authentication token for EKS cluster
data "aws_eks_cluster_auth" "app-cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Configure the Kubernetes provider with EKS cluster details
provider "kubernetes" {
  host                   = data.aws_eks_cluster.app-cluster.endpoint
  token                  = data.aws_eks_cluster_auth.app-cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.app-cluster.certificate_authority[0].data)
}

