# k8s-from-scratch-aws — Kubernetes on AWS with Terraform + Ansible

Provisions a Kubernetes cluster on AWS from scratch, designed for lab/dev environments with minimal AWS permissions.
Terraform builds the infrastructure; Ansible configures every node and bootstraps the cluster.

## Architecture

```
Internet
   │
   ▼
[Bastion (public subnet)]
   │  SSH proxy
   ▼
[Master(s) – private subnet]         [Workers ASG – private subnets]
   │  kubeadm init                        kubeadm join
   │  Calico CNI                          containerd
   └──────────────── pod network (192.168.0.0/16) ───────┘
```

| Component         | Detail                                      |
|-------------------|---------------------------------------------|
| Cloud             | AWS                                         |
| OS                | Ubuntu 22.04 LTS                            |
| Instance type     | t3.medium (master + workers), t3.micro (bastion) |
| Container runtime | containerd (SystemdCgroup = true)           |
| CNI               | Calico v3.27                                |
| Bootstrap         | kubeadm                                     |
| API access        | SSH through bastion (no NLB)                |
| State backend     | Local (S3 backend commented out)            |

## Prerequisites

| Tool         | Minimum version | Install                            |
|--------------|-----------------|------------------------------------|
| Terraform    | 1.5             | https://developer.hashicorp.com/terraform/downloads |
| Ansible      | 2.14            | `pip install ansible`              |
| AWS CLI      | 2.x             | https://aws.amazon.com/cli/        |
| Python boto3 | 1.26            | `pip install boto3`                |

AWS credentials must be exported before running any commands:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

Or use the helper scripts:

```bash
source scripts/load-env.sh      # Bash
. scripts/load-env.ps1          # PowerShell
```

## Deployment

### 1. Check prerequisites

```bash
bash scripts/check-prereqs.sh       # Bash
.\scripts\check-prereqs.ps1         # PowerShell
```

### 2. Provision infrastructure

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform writes two artefacts on success:
- `terraform/k8s-cluster.pem` — SSH private key (chmod 600, never commit)
- `ansible/inventory/hosts.ini` — Ansible static inventory

### 3. Verify connectivity

```bash
# SSH to bastion
BASTION_IP=$(terraform -chdir=terraform output -raw bastion_public_ip)
ssh -i terraform/k8s-cluster.pem ubuntu@$BASTION_IP

# Reach master via bastion
MASTER_IP=$(terraform -chdir=terraform output -json master_private_ips | python3 -c "import sys,json; print(json.load(sys.stdin)[0])")
ssh -i terraform/k8s-cluster.pem \
    -o ProxyCommand="ssh -i terraform/k8s-cluster.pem -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@$MASTER_IP
```

### 4. Run Ansible

```bash
cd ansible

# Test reachability
ansible -i inventory/hosts.ini all -m ping

# Full cluster bootstrap
ansible-playbook -i inventory/hosts.ini site.yml
```

Ansible steps:
1. **common** role — runs on every node: swap off, kernel modules, sysctl, containerd, kubeadm/kubelet/kubectl
2. **master** role — runs on master[0]: `kubeadm init`, Calico CNI, generates join command
3. **worker** role — runs on each worker (serial: 1): executes the join command

### 5. Access the cluster

After the playbook finishes, fetch the kubeconfig via bastion:

```bash
BASTION_IP=$(terraform -chdir=terraform output -raw bastion_public_ip)
MASTER_IP=$(terraform -chdir=terraform output -json master_private_ips | python3 -c "import sys,json; print(json.load(sys.stdin)[0])")

# Fetch kubeconfig
ssh -i terraform/k8s-cluster.pem \
    -o ProxyCommand="ssh -i terraform/k8s-cluster.pem -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@$MASTER_IP 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig

# Option A: run kubectl on the master via SSH
ssh -i terraform/k8s-cluster.pem \
    -o ProxyCommand="ssh -i terraform/k8s-cluster.pem -o StrictHostKeyChecking=no -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@$MASTER_IP 'kubectl get nodes'

# Option B: use an SSH tunnel for local kubectl
ssh -i terraform/k8s-cluster.pem -L 6443:$MASTER_IP:6443 ubuntu@$BASTION_IP -N &
sed -i "s|https://$MASTER_IP:6443|https://127.0.0.1:6443|" kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

## Scaling workers

Change `worker_count` in `terraform.tfvars`, then:

```bash
cd terraform && terraform apply
```

The Auto Scaling Group adjusts. New instances boot Ubuntu + Python (via user data), making them immediately reachable by Ansible.

Re-run the playbook — it is idempotent; nodes already in the cluster are skipped
(the `kubelet.conf` stat check prevents double-joining):

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

## Teardown

```bash
cd terraform
terraform destroy
```

## Security notes

- Worker and master nodes sit in **private subnets** — no public IPs.
- The bastion host is the **only SSH entry point** (`ssh_allowed_cidr` should be your IP, not `0.0.0.0/0` in production).
- The SSH private key is generated by `tls_private_key` and written locally as `terraform/k8s-cluster.pem`. It is marked `sensitive` in Terraform and must not be committed.
- No IAM roles or instance profiles are created — kept minimal for lab accounts.
- A single NAT gateway handles all private subnet egress.

## File layout

```
k8s-cluster/
├── terraform/
│   ├── providers.tf          Terraform + AWS provider versions
│   ├── backend.tf            Local state (S3 backend commented out)
│   ├── main.tf               Root module wiring VPC, security, compute
│   ├── variables.tf          All input variables with defaults
│   ├── outputs.tf            IPs, SSH commands
│   └── modules/
│       ├── vpc/              VPC, subnets, IGW, single NAT gateway, route tables
│       ├── compute/          Bastion, masters, worker ASG, key pair
│       └── security/         Security groups (bastion, master, worker)
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml              Orchestrating playbook
│   ├── inventory/
│   │   ├── hosts.ini         Generated by Terraform (static)
│   │   └── aws_ec2.yml       Dynamic inventory plugin config
│   ├── group_vars/
│   │   ├── all.yml           k8s version, CIDRs, Calico version
│   │   ├── masters.yml
│   │   └── workers.yml
│   └── roles/
│       ├── common/           Swap, modules, sysctl, containerd, kubeadm
│       ├── master/           kubeadm init, Calico, join command
│       ├── worker/           kubeadm join
│       └── ingress/          Helm + NGINX Ingress Controller
├── scripts/
│   ├── load-env.ps1/.sh      Load .env into shell session
│   └── check-prereqs.ps1/.sh Validate tools + AWS credentials
├── docs/diagrams/            Mermaid + PlantUML architecture diagrams
└── README.md
```
