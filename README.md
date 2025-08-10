# EKS Terraform Project

This project uses Terraform to provision an Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups on AWS.

---

## Folder Structure

eks-terraform-project/
├── main.tf          # Root Terraform configuration: calls VPC and EKS modules
├── variables.tf     # Input variables definitions with defaults and descriptions
├── outputs.tf       # Output values to expose cluster info and VPC details
├── provider.tf      # AWS provider configuration
├── iam.tf           # IAM roles and policies needed for EKS cluster control plane
└── kubeconfig.tf    # Writes local kubeconfig file to connect to the EKS cluster

---

## How the files connect

- **`iam.tf`**  
  Defines IAM roles and policies needed for the EKS control plane to function properly.

- **`kubeconfig.tf`**  
  Uses Terraform's `local_file` resource to write a Kubernetes config file from the EKS module outputs, so you can connect to your cluster using `kubectl`.

- **`outputs.tf`**  
  Exposes useful output variables such as:
  - EKS cluster endpoint URL  
  - Cluster name  
  - Kubeconfig content  
  - VPC ID and subnet IDs  

- **`main.tf`**  
  Calls the Terraform AWS VPC module to create networking resources and the Terraform AWS EKS module to create the cluster and managed node groups.

---

## Usage

1. **Set variables**  
   Update `terraform.tfvars` or override defaults in `variables.tf` as needed.

2. **Initialize Terraform**  
   ```bash
   terraform init
