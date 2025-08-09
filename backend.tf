terraform {
  backend "s3" {
    bucket = "whykay-backend-bucket"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
    profile = "whykay"  # Use the AWS profile configured in provider.tf
    # Optional:
    # encrypt = true
    # dynamodb_table = "terraform-lock-table"  # for state locking
  }
}
