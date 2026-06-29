output "private_key_pem" {
  description = "PEM-encoded private key — written to disk by the root module"
  value       = tls_private_key.k8s.private_key_pem
  sensitive   = true
}

output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.k8s.key_name
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "master_instance_ids" {
  description = "EC2 instance IDs of master nodes"
  value       = aws_instance.master[*].id
}

output "master_private_ips" {
  description = "Private IPs of master nodes"
  value       = aws_instance.master[*].private_ip
}

output "worker_private_ips" {
  description = "Private IPs of running worker instances (sampled at apply time)"
  value       = data.aws_instances.workers.private_ips
}

output "asg_name" {
  description = "Name of the worker Auto Scaling Group"
  value       = aws_autoscaling_group.workers.name
}
