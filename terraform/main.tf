data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ubuntu_ami_id != "" ? var.ubuntu_ami_id : data.aws_ami.ubuntu.id
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "security" {
  source = "./modules/security"

  cluster_name     = var.cluster_name
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "compute" {
  source = "./modules/compute"

  cluster_name          = var.cluster_name
  ami_id                = local.ami_id
  master_count          = var.master_count
  master_instance_type  = var.master_instance_type
  worker_count          = var.worker_count
  worker_min_count      = var.worker_min_count
  worker_max_count      = var.worker_max_count
  worker_instance_type  = var.worker_instance_type
  bastion_instance_type = var.bastion_instance_type
  private_subnet_ids    = module.vpc.private_subnet_ids
  public_subnet_ids     = module.vpc.public_subnet_ids
  master_sg_id          = module.security.master_sg_id
  worker_sg_id          = module.security.worker_sg_id
  bastion_sg_id         = module.security.bastion_sg_id
}

resource "local_file" "ansible_inventory" {
  filename        = var.ansible_inventory_path
  file_permission = "0600"
  content         = <<-INI
    [bastion]
    bastion ansible_host=${module.compute.bastion_public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${var.ansible_ssh_key_path}

    [masters]
    %{for idx, ip in module.compute.master_private_ips~}
    master-${idx + 1} ansible_host=${ip} ansible_user=ubuntu ansible_ssh_private_key_file=${var.ansible_ssh_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ${var.ansible_ssh_key_path} -o StrictHostKeyChecking=no -W %h:%p ubuntu@${module.compute.bastion_public_ip}"'
    %{endfor~}

    [workers]
    %{for idx, ip in module.compute.worker_private_ips~}
    worker-${idx + 1} ansible_host=${ip} ansible_user=ubuntu ansible_ssh_private_key_file=${var.ansible_ssh_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ${var.ansible_ssh_key_path} -o StrictHostKeyChecking=no -W %h:%p ubuntu@${module.compute.bastion_public_ip}"'
    %{endfor~}

    [k8s_cluster:children]
    masters
    workers

    [k8s_cluster:vars]
    pod_cidr=${var.pod_cidr}
    service_cidr=${var.service_cidr}
    kubernetes_version=${var.kubernetes_version}
  INI
}

resource "local_sensitive_file" "private_key" {
  content         = module.compute.private_key_pem
  filename        = "${path.module}/k8s-cluster.pem"
  file_permission = "0600"
}
