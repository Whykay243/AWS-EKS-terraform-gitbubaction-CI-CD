variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  default     = "my-eks-cluster"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired number of nodes in the EKS node group"
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of nodes in the EKS node group"
  default     = 3
}

variable "min_capacity" {
  description = "Minimum number of nodes in the EKS node group"
  default     = 1
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair to enable SSH access to nodes"
  type        = string
  default     = ""  # You can keep default empty if you want
}

