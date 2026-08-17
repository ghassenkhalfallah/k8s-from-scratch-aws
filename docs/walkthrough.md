# Project Walkthrough

## Terraform — builds the infrastructure

**Flow:** `variables.tf` → `main.tf` → 3 modules → `outputs.tf`

**`main.tf`** orchestrates everything. It calls three modules in order:

### 1. `modules/vpc/` — Creates the network
- 1 VPC (10.0.0.0/16)
- 2 public subnets (bastion lives here) + 2 private subnets (k8s nodes live here)
- 1 Internet Gateway for public subnets
- 1 NAT Gateway so private nodes can reach the internet (pull images, apt updates)
- Route tables wiring it all together

### 2. `modules/security/` — Creates 3 security groups (firewalls)
- **bastion-sg**: allows SSH (22) from your IP only
- **master-sg**: allows API server (6443), etcd (2379-2380), kubelet (10250), Calico (BGP 179, VXLAN 4789) — only from within VPC
- **worker-sg**: same as master + NodePort range (30000-32767)
- All three only accept SSH from the bastion SG — no direct access

### 3. `modules/compute/` — Creates the machines
- Generates an SSH key pair (tls_private_key → aws_key_pair)
- 1 bastion (t3.micro, public subnet) — your SSH jump point
- 1 master (t3.medium, private subnet) — runs control plane
- Worker ASG with launch template (t3.medium × N, private subnet) — runs pods

### After modules run
`main.tf` does two more things:
- Writes `ansible/inventory/hosts.ini` with all IPs and SSH ProxyCommand args
- Writes the SSH private key to `k8s-cluster.pem`

---

## Ansible — bootstraps Kubernetes

**Flow:** `site.yml` → 4 plays → 4 roles

### Play 1 — `common` role (runs on ALL nodes in parallel)
- Disables swap (k8s requirement)
- Loads kernel modules (`overlay`, `br_netfilter`) and sets sysctl for packet forwarding
- Installs containerd as container runtime, configures SystemdCgroup
- Adds Kubernetes apt repo, installs kubeadm + kubelet + kubectl, pins versions

### Play 2 — `master` role (runs on master[0] only)
- Renders `kubeadm-config.yml` with master's IP as controlPlaneEndpoint
- Runs `kubeadm init` — starts etcd, API server, controller-manager, scheduler, kube-proxy
- Copies kubeconfig to ubuntu user + fetches it locally
- Deploys Calico CNI, patches it to VXLAN mode
- Generates a join token and saves it

### Play 3 — `worker` role (runs on workers, `serial: 1`)
- Copies the join command from the controller
- Runs `kubeadm join` — registers the worker with the master
- Deletes the join script

### Play 4 — `ingress` role (runs on master[0])
- Installs Helm (if not present)
- Adds the ingress-nginx Helm repository
- Installs the NGINX Ingress Controller in `ingress-nginx` namespace
- Configured as NodePort (30080 HTTP, 30443 HTTPS) since there's no cloud LB
- All services can be exposed through a single entry point using Ingress resources

---

## The handoff

```
Terraform                          Ansible
   │                                  │
   ├─ creates VPC, SGs, EC2s          │
   ├─ writes hosts.ini ──────────────►├─ reads hosts.ini
   ├─ writes k8s-cluster.pem ────────►├─ uses key for SSH
   │                                  ├─ installs k8s components
   │                                  ├─ kubeadm init on master
   │                                  ├─ kubeadm join on workers
   │                                  ├─ install NGINX Ingress (Helm)
   │                                  └─ cluster ready
```

Terraform handles **what** gets created. Ansible handles **what runs on it**. The inventory file is the bridge between them.

---

## Ansible concepts

### Building blocks, bottom to top

**Task** — a single action:
```yaml
- name: Install nginx
  apt:
    name: nginx
    state: present
```

**Role** — a reusable folder of related tasks. Structure is standardized:
```
roles/common/
  tasks/main.yml      # what to do
  templates/           # config files with {{ variables }}
  handlers/main.yml    # triggered actions (e.g. restart service)
  files/               # static files to copy
```

**Play** — maps a role (or tasks) to a group of hosts:
```yaml
- name: Setup all nodes
  hosts: k8s_cluster      # from inventory
  roles:
    - common               # runs the common role
```

**Playbook** (`site.yml`) — a list of plays executed in order:
```yaml
- hosts: k8s_cluster       # Play 1: common on all nodes
  roles: [common]

- hosts: masters            # Play 2: master role on masters only
  roles: [master]

- hosts: workers            # Play 3: worker role on workers
  serial: 1                 # one at a time
  roles: [worker]
```

**Inventory** (`hosts.ini`) — defines the machines and groups:
```ini
[masters]
master-1 ansible_host=10.0.11.226

[workers]
worker-1 ansible_host=10.0.12.12
worker-2 ansible_host=10.0.11.242

[k8s_cluster:children]    # group of groups
masters
workers
```

### Key concepts
- **Idempotent** — run it 10 times, same result. Tasks check state before acting
- **Modules** — `apt`, `copy`, `template`, `command`, `file` — built-in actions Ansible knows how to do
- **Handlers** — tasks that only run when notified (e.g. restart containerd only if config changed)
- **group_vars/** — variables applied to all hosts in a group (e.g. `group_vars/all.yml` applies to everyone)
- **`become: true`** — run as root (sudo)
