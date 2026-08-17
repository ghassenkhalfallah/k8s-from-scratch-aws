output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host — use this to SSH into the cluster"
  value       = module.compute.bastion_public_ip
}

output "master_private_ips" {
  description = "Private IPs of master nodes"
  value       = module.compute.master_private_ips
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes (current ASG instances)"
  value       = module.compute.worker_private_ips
}

output "kubeconfig_command" {
  description = "Command to fetch the kubeconfig from the master node via bastion"
  value       = "ssh -J ubuntu@${module.compute.bastion_public_ip} ubuntu@${try(module.compute.master_private_ips[0], "N/A")} 'sudo cat /etc/kubernetes/admin.conf'"
}

output "ssh_to_bastion" {
  description = "SSH command to access the bastion host"
  value       = "ssh -i terraform/k8s-cluster.pem ubuntu@${module.compute.bastion_public_ip}"
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = var.ansible_inventory_path
}

output "private_key_path" {
  description = "Path to the generated SSH private key"
  value       = "${path.module}/k8s-cluster.pem"
  sensitive   = true
}
