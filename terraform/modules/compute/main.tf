resource "tls_private_key" "k8s" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s" {
  key_name   = "${var.cluster_name}-key"
  public_key = tls_private_key.k8s.public_key_openssh

  tags = {
    Name = "${var.cluster_name}-key"
  }
}

# ── Bastion ───────────────────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.bastion_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = aws_key_pair.k8s.key_name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3 python3-pip
  EOF

  tags = {
    Name = "${var.cluster_name}-bastion"
    Role = "bastion"
  }
}

# ── Master nodes ──────────────────────────────────────────────────────────────

resource "aws_instance" "master" {
  count                  = var.master_count
  ami                    = var.ami_id
  instance_type          = var.master_instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [var.master_sg_id]
  key_name               = aws_key_pair.k8s.key_name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3 python3-pip
    hostnamectl set-hostname ${var.cluster_name}-master-${count.index + 1}
  EOF

  tags = {
    Name              = "${var.cluster_name}-master-${count.index + 1}"
    Role              = "master"
    KubernetesCluster = var.cluster_name
  }
}

# ── Worker launch template ────────────────────────────────────────────────────

resource "aws_launch_template" "worker" {
  name_prefix   = "${var.cluster_name}-worker-"
  image_id      = var.ami_id
  instance_type = var.worker_instance_type
  key_name      = aws_key_pair.k8s.key_name

  vpc_security_group_ids = [var.worker_sg_id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp2"
      volume_size           = 30
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3 python3-pip
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    hostnamectl set-hostname ${var.cluster_name}-worker-$INSTANCE_ID
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name              = "${var.cluster_name}-worker"
      Role              = "worker"
      KubernetesCluster = var.cluster_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name              = "${var.cluster_name}-worker-volume"
      KubernetesCluster = var.cluster_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers" {
  name                = "${var.cluster_name}-workers-asg"
  desired_capacity    = var.worker_count
  min_size            = var.worker_min_count
  max_size            = var.worker_max_count
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
  wait_for_capacity_timeout = "10m"

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "KubernetesCluster"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ── Worker IPs (best-effort from current ASG instances) ───────────────────────

data "aws_instances" "workers" {
  filter {
    name   = "tag:KubernetesCluster"
    values = [var.cluster_name]
  }

  filter {
    name   = "tag:Role"
    values = ["worker"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running", "pending"]
  }

  depends_on = [aws_autoscaling_group.workers]
}
