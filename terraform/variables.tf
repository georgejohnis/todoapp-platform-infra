variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
  default     = "vpc-6d719a08"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "todo-app-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"  # Latest available version
}

# We'll need to get the subnet IDs from your VPC
variable "subnet_ids" {
  description = "List of subnet IDs from the existing VPC for EKS cluster"
  type        = list(string)
  default     = [
    "subnet-1b3d236f",  # us-west-2a
    "subnet-47b44d22",  # us-west-2b
    "subnet-a6a49ae0",  # us-west-2c
    "subnet-2de1ae05"   # us-west-2d
  ]
}

variable "gitops_repo_url" {
  description = "The URL of the Git repository containing the GitOps configurations"
  type        = string
}
