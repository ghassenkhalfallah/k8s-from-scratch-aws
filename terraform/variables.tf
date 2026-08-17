variable "aws_region" {
  description = "AWS region to deploy the cluster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name prefix used for all resources"
  type        = string
  default     = "k8s-cluster"
}

variable "environment" {
  description = "Deployment environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "master_count" {
  description = "Number of Kubernetes master nodes (1 for single master, 3 for HA)"
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3], var.master_count)
    error_message = "master_count must be 1 (single master) or 3 (HA)."
  }
}

variable "worker_count" {
  description = "Desired number of Kubernetes worker nodes in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "worker_min_count" {
  description = "Minimum number of worker nodes in the ASG"
  type        = number
  default     = 1
}

variable "worker_max_count" {
  description = "Maximum number of worker nodes in the ASG"
  type        = number
  default     = 10
}

variable "master_instance_type" {
  description = "EC2 instance type for master nodes"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "ubuntu_ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS. Leave empty to auto-lookup latest in the region."
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the bastion host"
  type        = string
  default     = "0.0.0.0/0"
}

variable "kubernetes_version" {
  description = "Kubernetes version to install (e.g. 1.29)"
  type        = string
  default     = "1.29"
}

variable "pod_cidr" {
  description = "CIDR block for Kubernetes pods (used by Calico)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "ansible_inventory_path" {
  description = "Local path where Terraform writes the generated Ansible inventory file"
  type        = string
  default     = "../ansible/inventory/hosts.ini"
}

variable "ansible_ssh_key_path" {
  description = "Path to the SSH private key used in the Ansible inventory. Use /tmp/k8s-cluster.pem for WSL."
  type        = string
  default     = "/tmp/k8s-cluster.pem"
}
