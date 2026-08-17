variable "cluster_name" {
  description = "Cluster name prefix for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to attach security groups to"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block — used for inter-node communication rules"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block permitted to SSH into the bastion host"
  type        = string
}
