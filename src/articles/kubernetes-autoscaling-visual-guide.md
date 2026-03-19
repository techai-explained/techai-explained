---
title: "Kubernetes Autoscaling: A Visual Guide"
description: "A complete visual guide to Kubernetes autoscaling — HPA, VPA, Cluster Autoscaler, and KEDA — with practical examples and decision frameworks."
date: 2026-03-16
tags: ["DevOps"]
readTime: "13 min read"
---

Kubernetes autoscaling sounds simple: "add more pods when traffic goes up." In reality, there are four different autoscaling mechanisms, each solving a different problem. Picking the wrong one — or misconfiguring the right one — leads to either wasted money or dropped requests.

This visual guide covers all four autoscalers, when to use each, and the configuration patterns that work in production.

## The Autoscaling Landscape

<div class="diagram-box">
┌─────────────────────────────────────────────────────┐
│            KUBERNETES AUTOSCALING STACK              │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │         CLUSTER AUTOSCALER                  │    │
│  │     Adds/removes NODES from the cluster     │    │
│  └─────────────────────┬───────────────────────┘    │
│                        │                            │
│  ┌─────────────────────┼───────────────────────┐    │
│  │      NODE           │          NODE          │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │    │
│  │  │   HPA    │  │   VPA    │  │   KEDA   │   │    │
│  │  │ Scales   │  │ Resizes  │  │ Event-   │   │    │
│  │  │ pod      │  │ pod      │  │ driven   │   │    │
│  │  │ COUNT    │  │ RESOURCES│  │ scaling  │   │    │
│  │  └──────────┘  └──────────┘  └──────────┘   │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
</div>

- **HPA** (Horizontal Pod Autoscaler): scales the **number** of pods
- **VPA** (Vertical Pod Autoscaler): scales the **resources** of each pod
- **Cluster Autoscaler**: scales the **number of nodes**
- **KEDA**: event-driven autoscaling based on **external metrics**

## 1. Horizontal Pod Autoscaler (HPA)

The HPA watches a metric (CPU, memory, or custom metrics) and adjusts the replica count of a Deployment or StatefulSet.

### How It Works

<div class="diagram-box">
                    Metrics Server
                         │
                    ┌────┴────┐
                    │ Current │
                    │ CPU: 80%│
                    │ Target: │
                    │ 50%     │
                    └────┬────┘
                         │
                    ┌────┴────┐
                    │   HPA   │
                    │ Formula:│
                    │ desired │
                    │= ceil(  │
                    │ current │
                    │/ target │
                    │* replicas│
                    │)        │
                    └────┬────┘
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
       ┌────────┐  ┌────────┐  ┌────────┐
       │ Pod 1  │  │ Pod 2  │  │ Pod 3  │
       │(exists)│  │(exists)│  │ (NEW)  │
       └────────┘  └────────┘  └────────┘
</div>

The scaling formula: `desiredReplicas = ceil(currentMetricValue / targetMetricValue × currentReplicas)`

If you have 2 pods at 80% CPU with a target of 50%, the HPA calculates: `ceil(80/50 × 2) = ceil(3.2) = 4 pods`.

### Basic HPA Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 75
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 25
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
        - type: Pods
          value: 4
          periodSeconds: 60
      selectPolicy: Max
```

### Critical: The Behavior Section

The `behavior` section controls **how fast** scaling happens. Without it, the HPA uses defaults that can cause oscillation.

**Scale-up strategy:**
- React quickly — 30-second stabilization window
- Allow doubling (100% increase) or adding 4 pods, whichever is more
- Use `selectPolicy: Max` to pick the more aggressive option

**Scale-down strategy:**
- React slowly — 300-second (5 minute) stabilization window
- Remove at most 25% of pods per minute
- This prevents thrashing during traffic fluctuations

### HPA with Custom Metrics

CPU and memory aren't always the right signals. For a web API, requests-per-second is more meaningful:

```yaml
metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: 1000
```

This scales based on actual traffic rather than resource utilization.

## 2. Vertical Pod Autoscaler (VPA)

While HPA adds more pods, VPA makes existing pods bigger (or smaller). It adjusts CPU and memory requests and limits.

### When VPA Wins Over HPA

- **Stateful workloads** — databases, caches, queues that can't easily be horizontally scaled
- **Batch jobs** — jobs that need varying resources based on input size
- **Right-sizing** — finding the correct resource requests for your workloads

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: database-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: postgres
  updatePolicy:
    updateMode: "Auto"  # or "Off" for recommendation-only
  resourcePolicy:
    containerPolicies:
      - containerName: postgres
        minAllowed:
          cpu: 250m
          memory: 512Mi
        maxAllowed:
          cpu: 4
          memory: 8Gi
        controlledResources: ["cpu", "memory"]
```

> **Warning**: VPA and HPA should **not** both target CPU/memory on the same workload. They'll fight each other. If you need both, use HPA with custom metrics and VPA for resource right-sizing.

### VPA Modes

| Mode | Behavior |
|------|----------|
| `Off` | Only provides recommendations; doesn't change anything |
| `Initial` | Sets resources only when pods are first created |
| `Auto` | Evicts and recreates pods with updated resources |

**Best practice**: Start with `Off` to see recommendations, then move to `Auto` once you trust the suggestions.

## 3. Cluster Autoscaler

HPA and VPA scale pods. But what if there aren't enough nodes to schedule those pods? The Cluster Autoscaler handles this.

<div class="diagram-box">
┌────────────────────────────────────────────────┐
│               CLUSTER AUTOSCALER               │
│                                                │
│  SCALE UP trigger:                             │
│  Pod is "Pending" because no node has enough   │
│  resources to schedule it.                     │
│                                                │
│  ┌──────┐ ┌──────┐ ┌──────┐                   │
│  │Node 1│ │Node 2│ │Node 3│  ← All full       │
│  │[████]│ │[████]│ │[████]│                    │
│  └──────┘ └──────┘ └──────┘                    │
│                              ┌──────┐          │
│  Pending pod ──────────────► │Node 4│ NEW!     │
│                              │[█   ]│          │
│                              └──────┘          │
│                                                │
│  SCALE DOWN trigger:                           │
│  Node utilization < 50% for 10+ minutes AND    │
│  all pods can be rescheduled on other nodes.   │
└────────────────────────────────────────────────┘
</div>

### Cloud Provider Integration

The Cluster Autoscaler works with cloud provider node pools:

```yaml
# AKS example: node pool with autoscaling
az aks nodepool add \
  --resource-group myRG \
  --cluster-name myCluster \
  --name workerpool \
  --node-count 3 \
  --min-count 2 \
  --max-count 20 \
  --enable-cluster-autoscaler \
  --node-vm-size Standard_D4s_v3
```

### Key Configuration Options

```yaml
# Cluster Autoscaler ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-config
data:
  # Wait 10 minutes before removing underutilized nodes
  scale-down-unneeded-time: "10m"
  
  # Node must be below 50% utilization to be considered
  scale-down-utilization-threshold: "0.5"
  
  # Don't scale down if it would remove the last node
  skip-nodes-with-system-pods: "true"
  
  # Maximum time to wait for a node to become ready
  max-node-provision-time: "15m"
```

## 4. KEDA: Event-Driven Autoscaling

KEDA (Kubernetes Event-Driven Autoscaling) is the most flexible option. It scales based on external event sources — message queues, databases, cron schedules, and 60+ other scalers.

### When KEDA Shines

- **Queue-based workloads**: scale workers based on queue depth
- **Event processing**: scale consumers based on event lag
- **Scheduled scaling**: scale up before known traffic spikes
- **Scale to zero**: shut down completely when there's no work

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor
spec:
  scaleTargetRef:
    name: order-processor
  minReplicaCount: 0     # Scale to zero!
  maxReplicaCount: 50
  cooldownPeriod: 60
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: orders
        messageCount: "5"  # 1 pod per 5 messages
        connectionFromEnv: SB_CONNECTION
    - type: cron
      metadata:
        timezone: America/Los_Angeles
        start: "0 8 * * 1-5"   # 8 AM weekdays
        end: "0 20 * * 1-5"    # 8 PM weekdays
        desiredReplicas: "3"   # Pre-warm during business hours
```

### KEDA Architecture

<div class="diagram-box">
┌──────────────┐     ┌──────────────┐
│  External    │     │    KEDA      │
│  Source       │────►│   Metrics    │
│  (Queue,     │     │   Adapter    │
│   DB, etc.)  │     └──────┬───────┘
└──────────────┘            │
                            ▼
                    ┌──────────────┐
                    │     HPA      │
                    │  (created by │
                    │   KEDA)      │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌────────┐  ┌────────┐  ┌────────┐
         │Worker 1│  │Worker 2│  │Worker 3│
         └────────┘  └────────┘  └────────┘
</div>

KEDA creates and manages an HPA under the hood, feeding it with metrics from external sources.

## Decision Framework

Use this flowchart to pick the right autoscaler:

<div class="diagram-box">
Is your workload stateless?
├── YES: Can it be horizontally scaled?
│   ├── YES: Does it respond to external events?
│   │   ├── YES ──────────► KEDA
│   │   └── NO: Is CPU/memory the right metric?
│   │       ├── YES ──────► HPA (resource metrics)
│   │       └── NO ───────► HPA (custom metrics)
│   └── NO ───────────────► VPA
└── NO ───────────────────► VPA + Manual planning

Always pair with Cluster Autoscaler for node-level scaling.
</div>

## Production Checklist

Before going live with autoscaling, verify these items:

### Resource Requests and Limits

Autoscaling only works if your pods have proper resource requests:

```yaml
resources:
  requests:
    cpu: 250m       # Used by HPA for calculations
    memory: 256Mi   # Used by VPA for recommendations
  limits:
    cpu: 1000m      # Hard ceiling
    memory: 512Mi   # OOM-killed if exceeded
```

**Without requests, HPA has nothing to measure.**

### Pod Disruption Budgets

Prevent autoscaling from killing too many pods at once:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: "75%"
  selector:
    matchLabels:
      app: web-app
```

### Readiness Probes

New pods must only receive traffic when they're actually ready:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

### Monitoring Dashboards

Track these metrics:
- **Replica count over time** — are you scaling smoothly or oscillating?
- **Pod startup time** — slow starts mean scaling can't keep up with traffic spikes
- **Pending pods** — if pods are pending, the Cluster Autoscaler might be too slow
- **Cost per request** — autoscaling should decrease this number, not increase it

## Common Mistakes

1. **Setting minReplicas to 1** — no high availability during scale-up delays
2. **No stabilization window** — causes rapid scaling up and down (thrashing)
3. **Ignoring pod startup time** — if pods take 60s to start, your scale-up is always 60s too late
4. **VPA + HPA on same CPU metric** — they conflict and create feedback loops
5. **Not setting maxReplicas** — a traffic spike could autoscale you into a $50K cloud bill

## Summary

| Autoscaler | Scales | Based On | Key Config |
|-----------|--------|----------|------------|
| HPA | Pod count | CPU, memory, custom metrics | `behavior`, `minReplicas`, `maxReplicas` |
| VPA | Pod resources | Historical usage | `updateMode`, `minAllowed`, `maxAllowed` |
| Cluster Autoscaler | Node count | Pending pods | `min-count`, `max-count`, provider config |
| KEDA | Pod count (to zero) | External events | `triggers`, `cooldownPeriod` |

Start with HPA for stateless web services, add KEDA for event-driven workloads, use VPA for stateful services, and always enable the Cluster Autoscaler. Layer them intentionally, monitor aggressively, and iterate based on real traffic patterns.

*Published by the TechAI Explained Team.*
