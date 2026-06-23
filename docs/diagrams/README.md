# Architecture Diagrams

## Files

| File | Format | Content |
|------|--------|---------|
| [01-infrastructure.mmd](01-infrastructure.mmd) | Mermaid | Full AWS infrastructure topology — VPC, subnets, EC2, NLB, NAT |
| [02-network-flows.mmd](02-network-flows.mmd) | Mermaid | Security group rules and traffic flow paths |
| [03-deployment-sequence.mmd](03-deployment-sequence.mmd) | Mermaid | Step-by-step sequence: Terraform → Ansible → kubeadm |
| [04-kubernetes-components.mmd](04-kubernetes-components.mmd) | Mermaid | Kubernetes components per node type (control-plane vs worker) |
| [05-scaling.mmd](05-scaling.mmd) | Mermaid | Scale-out and scale-in workflows |
| [architecture.puml](architecture.puml) | PlantUML | Full architecture with security group annotations and IAM notes |

## How to render

### Mermaid (`.mmd`)

**Option A — VS Code**
Install the [Mermaid Preview](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-mermaid) extension, then open any `.mmd` file and press `Ctrl+Shift+V`.

**Option B — CLI**
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i 01-infrastructure.mmd -o 01-infrastructure.png -t dark
```

**Option C — GitHub / GitLab**
Both platforms render Mermaid blocks natively inside Markdown fences:
~~~markdown
```mermaid
<paste file content here>
```
~~~

**Option D — Browser**
Paste the file content at https://mermaid.live

### PlantUML (`.puml`)

**Option A — VS Code**
Install the [PlantUML](https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml) extension (requires Java or the PlantUML server).

**Option B — CLI**
```bash
java -jar plantuml.jar architecture.puml
# outputs architecture.png
```

**Option C — Browser**
Paste the file content at https://www.plantuml.com/plantuml/uml/
