# Portfolio Roadmap

## Tier 1 — Must-haves (production awareness)
- [x] Ingress Controller (NGINX Ingress) — cert-manager TLS pending
- [x] Monitoring stack (Prometheus + Grafana via Helm, deployed via GitOps app-of-apps)
- [x] GitOps (ArgoCD)
- [ ] Remote Terraform state (S3 + DynamoDB backend)

## Tier 2 — Differentiators (stands out)
- [ ] CI/CD pipeline (GitHub Actions: lint Terraform, ansible-lint, deploy)
- [ ] HA control plane (3 masters + NLB)
- [ ] Network Policies (Calico zero-trust pod-to-pod rules)
- [ ] Helm charts for sample apps

## Tier 3 — Advanced (senior-level signal)
- [ ] Logging (Loki + Promtail or EFK stack)
- [ ] HPA/VPA auto-scaling
- [ ] Backup/restore (Velero)
- [ ] Service Mesh (Istio or Linkerd)
