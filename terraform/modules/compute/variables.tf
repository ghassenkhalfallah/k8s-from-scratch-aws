variable "cluster_name" {
  description = "Cluster name prefix for resource naming"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for all EC2 instances"
  type        = string
}

variable "master_count" {
  description = "Number of master nodes to create"
  type        = number
}

variable "master_instance_type" {
  description = "EC2 instance type for master nodes"
  type        = string
}

variable "worker_count" {
  description = "Desired number of worker nodes in the ASG"
  type        = number
}

variable "worker_min_count" {
  description = "Minimum ASG capacity"
  type        = number
}

variable "worker_max_count" {
  description = "Maximum ASG capacity"
  type        = number
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for master and worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the bastion host"
  type        = list(string)
}

variable "master_sg_id" {
  description = "Security group ID for master nodes"
  type        = string
}

variable "worker_sg_id" {
  description = "Security group ID for worker nodes"
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for the bastion host"
  type        = string
}
