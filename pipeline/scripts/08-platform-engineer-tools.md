---
title: "The 5 Tools Every Platform Engineer Uses Daily"
duration: "10 minutes"
voice: "en-US-GuyNeural"
---

## [TITLE] The 5 Tools Every Platform Engineer Uses Daily
From internal developer portals to cost management — the essential toolkit that powers modern platform engineering.

## [BULLETS] Why Platform Engineering Exists
- Developers shouldn't need to understand Kubernetes networking to deploy an app
- DevOps "you build it, you run it" created too much cognitive load
- Platform teams build golden paths — paved roads that make the right thing the easy thing
- The goal: self-service infrastructure with guardrails, not gatekeepers
- These five tools are the backbone of nearly every modern platform team

## [DIAGRAM] Tool 1: Backstage — Internal Developer Portal
```
┌─────────────────────────────────────────────────┐
│                  BACKSTAGE                       │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Software │  │ Tech     │  │  API          │  │
│  │ Catalog  │  │ Docs     │  │  Explorer     │  │
│  │          │  │          │  │               │  │
│  │ Services │  │ Markdown │  │  OpenAPI /    │  │
│  │ APIs     │  │ rendered │  │  gRPC specs   │  │
│  │ Teams    │  │ in-place │  │  auto-indexed │  │
│  └──────────┘  └──────────┘  └───────────────┘  │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Software │  │ Cost     │  │  CI/CD        │  │
│  │ Templates│  │ Insights │  │  Dashboard    │  │
│  │          │  │          │  │               │  │
│  │ Scaffold │  │ Per-team │  │  Build status │  │
│  │ new apps │  │ spending │  │  Deploy logs  │  │
│  └──────────┘  └──────────┘  └───────────────┘  │
└─────────────────────────────────────────────────┘
```
Backstage is the single pane of glass for developer self-service. One portal to find services, read docs, create new projects, and see what's running.

## [CODE] Backstage — Defining a Component in the Catalog
```yaml
# catalog-info.yaml — lives in each service repo
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payment-service
  description: Handles payment processing and refunds
  annotations:
    github.com/project-slug: org/payment-service
    backstage.io/techdocs-ref: dir:.
    argocd/app-name: payment-service-prod
    grafana/dashboard-selector: payment
  tags:
    - python
    - grpc
    - tier-1
spec:
  type: service
  lifecycle: production
  owner: team-payments
  system: checkout-platform
  dependsOn:
    - component:fraud-detection
    - resource:payments-database
  providesApis:
    - payment-api
```

## [DIAGRAM] Tool 2: ArgoCD — GitOps Deployment
```
┌──────────┐   push    ┌──────────────┐
│  Git     │──────────▶│   ArgoCD     │
│  Repo    │           │              │
│          │◀──────────│  Watches for │
│ manifests│   sync    │  drift       │
└──────────┘           └──────┬───────┘
                              │
                    ┌─────────▼──────────┐
                    │  Kubernetes Cluster │
                    │                    │
                    │  Desired State     │
                    │  == Live State     │
                    │                    │
                    │  Auto-sync or      │
                    │  manual approval   │
                    └────────────────────┘

GitOps Principle:
  Git is the single source of truth.
  No kubectl apply. No manual changes.
  Everything goes through a PR.
```

## [COMPARISON] Tool 3: Infrastructure as Code — Crossplane vs Terraform
| Feature               | Crossplane              | Terraform                |
|-----------------------|-------------------------|--------------------------|
| Execution model       | Kubernetes controller   | CLI / CI runner          |
| State management      | In-cluster (CRDs)       | State file (S3, etc.)   |
| Drift detection       | Continuous reconciliation| On `terraform plan`     |
| Language              | YAML (K8s manifests)    | HCL                      |
| Multi-cloud           | ✅ Via providers         | ✅ Via providers          |
| Self-service          | Native (K8s RBAC)       | Requires wrapper tooling |
| Learning curve        | Steeper (K8s knowledge) | Moderate                 |
| Community size        | Growing                 | Very large               |
| Best for              | K8s-native platforms    | Broad infrastructure     |

## [CODE] Crossplane — Provisioning a Database via YAML
```yaml
# A developer requests a database — no tickets, no waiting
apiVersion: database.platform.io/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: orders-db
  namespace: team-orders
spec:
  parameters:
    storageGB: 50
    version: "15"
    highAvailability: true
  compositionSelector:
    matchLabels:
      provider: aws
      environment: production
  writeConnectionSecretToRef:
    name: orders-db-credentials
    namespace: team-orders
# Platform team defines what "PostgreSQLInstance" provisions
# behind the scenes — RDS, security groups, IAM, backups
```

## [DIAGRAM] Tool 4: Grafana Stack — Observability
```
┌───────────────────────────────────────────────────┐
│                  GRAFANA STACK                     │
│                                                    │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────┐  │
│  │   Grafana    │  │  Loki    │  │  Tempo       │  │
│  │             │  │          │  │              │  │
│  │ Dashboards  │  │  Logs    │  │  Traces      │  │
│  │ Alerts      │  │  LogQL   │  │  TraceQL     │  │
│  │ Explore     │  │          │  │              │  │
│  └──────┬──────┘  └────┬─────┘  └──────┬───────┘  │
│         │              │               │           │
│         └──────────────┼───────────────┘           │
│                        │                           │
│                ┌───────▼────────┐                   │
│                │   Mimir        │                   │
│                │   Metrics      │                   │
│                │   PromQL       │                   │
│                └────────────────┘                   │
│                                                    │
│  Correlation: Click a metric spike → see logs →    │
│  jump to trace → find the root cause               │
└───────────────────────────────────────────────────┘

  Data flows in via OpenTelemetry Collector
  ┌─────────┐     ┌─────────────────┐
  │  Apps   │────▶│  OTel Collector │──▶ Mimir/Loki/Tempo
  └─────────┘     └─────────────────┘
```

## [BULLETS] Tool 5: Kubecost / OpenCost — Cost Management
- **Real-time cost allocation** — see spend per team, namespace, and service
- **Cost per request** — tie infrastructure cost to actual traffic
- **Idle resource detection** — find over-provisioned pods and unused volumes
- **Budget alerts** — notify teams before they exceed spending thresholds
- **Right-sizing recommendations** — suggest CPU/memory limits based on actual usage
- **Showback reports** — give teams visibility without chargeback complexity
- **OpenCost** is the CNCF open-source standard; Kubecost adds enterprise features

## [CODE] Kubecost — Querying Cost Data via API
```bash
# Get cost breakdown by namespace for the last 7 days
curl -s "http://kubecost.internal/model/allocation?window=7d\
  &aggregate=namespace\
  &accumulate=true" | jq '.data[] | to_entries[] | {
    namespace: .key,
    totalCost: (.value.totalCost | round),
    cpuCost: (.value.cpuCost | round),
    ramCost: (.value.ramCost | round),
    efficiency: ((.value.totalEfficiency * 100) | round)
  }'

# Example output:
# { "namespace": "team-payments", "totalCost": 1240,
#   "cpuCost": 680, "ramCost": 420, "efficiency": 34 }
# { "namespace": "team-orders", "totalCost": 890,
#   "cpuCost": 510, "ramCost": 310, "efficiency": 67 }
```

## [DIAGRAM] How All 5 Tools Connect Together
```
                    ┌─────────────────┐
                    │    BACKSTAGE     │
                    │  (Developer      │
                    │   Portal)        │
                    └───┬─────┬───┬───┘
           ┌────────────┘     │   └────────────┐
           ▼                  ▼                ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │   ArgoCD     │  │  Grafana     │  │  Kubecost    │
    │  (Deploy)    │  │  (Observe)   │  │  (Cost)      │
    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
           │                 │                 │
           └────────────┬────┘                 │
                        ▼                      │
              ┌──────────────────┐             │
              │   Kubernetes     │◀────────────┘
              │   Cluster(s)     │
              └────────┬─────────┘
                       │
              ┌────────▼─────────┐
              │  Crossplane /    │
              │  Terraform       │
              │  (Infra as Code) │
              └──────────────────┘

Developer Flow:
  Backstage → Create service from template
  → ArgoCD deploys it → Grafana monitors it
  → Kubecost tracks spend → Crossplane provisions infra
```

## [BULLETS] Getting Started Recommendations
- **Start with Backstage** — catalog what you already have before building new things
- **Add ArgoCD next** — GitOps is the foundation for repeatable, auditable deployments
- **Layer in observability** — Grafana stack with OpenTelemetry gives you full visibility
- **Then cost management** — you can't optimize what you can't measure
- **IaC last** — Crossplane or Terraform for self-service infrastructure provisioning
- **Go incremental** — don't try to build the entire platform at once

## [QUOTE] The Platform Engineering Mindset
"A great platform is invisible. Developers don't think about infrastructure — they think about their product. The five tools above are how platform teams make that invisibility possible."
