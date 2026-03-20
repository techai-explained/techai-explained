---
title: "Microservices Are Dead? What Actually Replaced Them"
duration: "11 minutes"
voice: "en-US-GuyNeural"
---

## [TITLE] Microservices Are Dead?
What Actually Replaced Them

## [COMPARISON] The Promise vs The Reality
| The Promise | The Reality |
|-------------|-------------|
| Independent deployments | 47 repos to update for one feature |
| Team autonomy | Three teams needed for a single API change |
| Scale what you need | Everything scales — and so does the AWS bill |
| Technology freedom | 6 languages, 4 ORMs, nobody can debug anything |
| Fault isolation | Cascading failures across 200 services |
| Faster development | Slower — distributed debugging takes 10x longer |

## [BULLETS] The Three Costs Nobody Warned You About
- **Operational cost**: service mesh, distributed tracing, circuit breakers, API gateways, container orchestration — all required infrastructure
- **Cognitive cost**: developers must understand network failure modes, eventual consistency, distributed transactions, and saga patterns
- **Organizational cost**: you need DevOps, SRE, and platform teams just to keep the lights on
- The total cost is often 5–10x higher than a well-structured monolith
- Most teams discovered this after the migration, not before

## [BULLETS] Who Told Us Microservices Were the Answer?
- Netflix, Amazon, Google — companies with thousands of engineers and millions of users
- Their scale demanded distributed systems — yours probably does not
- The industry confused "works at Netflix scale" with "works for everyone"
- Conference talks celebrated the architecture but skipped the operational horror stories
- The pendulum is swinging back — and the alternatives are maturing

## [DIAGRAM] Pattern 1: The Modular Monolith
```
  ┌─────────────────────────────────────────────────────┐
  │                SINGLE DEPLOYMENT UNIT                 │
  │                                                       │
  │  ┌───────────┐  ┌───────────┐  ┌───────────┐        │
  │  │  Orders   │  │  Payments │  │  Users    │        │
  │  │  Module   │  │  Module   │  │  Module   │        │
  │  │           │  │           │  │           │        │
  │  │ • routes  │  │ • routes  │  │ • routes  │        │
  │  │ • logic   │  │ • logic   │  │ • logic   │        │
  │  │ • models  │  │ • models  │  │ • models  │        │
  │  │ • tests   │  │ • tests   │  │ • tests   │        │
  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘        │
  │        │              │              │               │
  │  ┌─────▼──────────────▼──────────────▼─────┐        │
  │  │          Shared Infrastructure           │        │
  │  │    (DB, auth, logging, messaging)        │        │
  │  └─────────────────────────────────────────┘        │
  │                                                       │
  │  KEY RULES:                                           │
  │  • Modules communicate via well-defined interfaces    │
  │  • No direct database access across module boundaries │
  │  • Each module can be extracted to a service later     │
  │  • Enforced by build tooling, not just convention      │
  └───────────────────────────────────────────────────────┘
```

## [BULLETS] Why the Modular Monolith Works
- One deployment, one repo, one debugging session
- Module boundaries enforce separation without network overhead
- Refactoring is an IDE operation, not a multi-repo coordination exercise
- Performance: function calls are nanoseconds, HTTP calls are milliseconds
- Testing: integration tests run in-process — fast and reliable
- Extraction path: if a module truly needs to scale independently, extract it then

## [BULLETS] Pattern 2: Macroservices
- Instead of 200 microservices, use 5–10 larger services aligned to business domains
- Each macroservice owns a full bounded context — not a single entity
- Example: "Commerce Service" instead of separate Cart, Inventory, Pricing, Catalog services
- Fewer services = fewer network hops, fewer failure points, fewer repos
- Teams own a whole macroservice — no cross-team coordination for basic features
- This is what most companies actually need

## [DIAGRAM] Pattern 3: Platform Engineering
```
  ┌──────────────────────────────────────────────────┐
  │                  DEVELOPERS                       │
  │                                                   │
  │   "deploy my-app"     "create database"           │
  │   "add queue"         "view logs"                 │
  │                                                   │
  └──────────────────────┬───────────────────────────┘
                         │
                         ▼
  ┌──────────────────────────────────────────────────┐
  │          INTERNAL DEVELOPER PLATFORM              │
  │                                                   │
  │  ┌────────────┐ ┌──────────┐ ┌───────────────┐  │
  │  │ Service    │ │ Self-    │ │ Golden Paths  │  │
  │  │ Catalog    │ │ Service  │ │ & Templates   │  │
  │  │ (Backstage)│ │ Portal   │ │               │  │
  │  └────────────┘ └──────────┘ └───────────────┘  │
  │                                                   │
  └──────────────────────┬───────────────────────────┘
                         │
                         ▼
  ┌──────────────────────────────────────────────────┐
  │           INFRASTRUCTURE LAYER                    │
  │  (Kubernetes, Terraform, CI/CD, observability)    │
  │                                                   │
  │  Developers never touch this directly.            │
  │  The platform team abstracts it away.             │
  └──────────────────────────────────────────────────┘
```

## [BULLETS] Real-World Case Studies
- **Amazon Prime Video**: moved their monitoring pipeline from microservices to a monolith — reduced costs by 90% and simplified operations
- **Shopify**: built one of the largest Ruby on Rails modular monoliths — serves billions of requests per day from a single codebase
- **Segment**: migrated from 140+ microservices back to a monolith — developer velocity increased dramatically
- The lesson: architecture should match your organization's size and complexity, not your ambition

## [COMPARISON] When to Use What
| Architecture | Team Size | Services | Best For |
|-------------|-----------|----------|----------|
| Monolith | 1–10 devs | 1 | MVPs, startups, most apps |
| Modular Monolith | 10–50 devs | 1 (with modules) | Growing companies, complex domains |
| Macroservices | 20–100 devs | 5–10 | Mid-size companies, clear domain boundaries |
| Microservices | 100+ devs | 50+ | Netflix-scale, independent team deployment |
| Serverless | 1–30 devs | Event-driven | Event processing, APIs, glue code |

## [BULLETS] When Microservices Still Make Sense
- You have hundreds of engineers who need to deploy independently
- Different services have genuinely different scaling requirements (10x difference)
- Regulatory boundaries require hard isolation between domains
- You can invest in a dedicated platform engineering team
- You have already outgrown a modular monolith through measured scaling
- The key word is **earned complexity** — not premature architecture

## [DIAGRAM] The Architecture Decision Flowchart
```
                       START
                         │
              ┌──────────▼───────────┐
              │  More than 100       │
              │  engineers?          │
              └──────────┬───────────┘
                    NO / \ YES
                   /       \
      ┌───────────▼─┐  ┌───▼───────────────┐
      │ More than   │  │ Do teams need to   │
      │ 10 devs?   │  │ deploy completely  │
      │             │  │ independently?     │
      └──────┬──────┘  └───┬───────────────┘
        NO / \ YES    NO / \ YES
       /       \      /       \
  ┌───▼────┐ ┌─▼────▼──┐  ┌──▼──────────┐
  │MONOLITH│ │ MODULAR  │  │MICROSERVICES│
  │        │ │ MONOLITH │  │(with a      │
  │ Keep it│ │ or       │  │ platform    │
  │ simple │ │ MACRO-   │  │ team)       │
  │        │ │ SERVICES │  │             │
  └────────┘ └──────────┘  └─────────────┘
```

## [QUOTE] Words from the Trenches
> "If you can't build a well-structured monolith, what makes you think microservices are the answer?"
> — Common industry wisdom

> "We moved to microservices because everyone else did. We moved back because we measured."
> — Segment engineering retrospective

## [BULLETS] Key Takeaways
- Microservices are not dead — but they are no longer the default answer
- The modular monolith is the sweet spot for most teams
- Macroservices offer distributed benefits without micro-scale complexity
- Platform engineering makes any architecture more manageable
- Match your architecture to your team size and actual scaling needs
- Start simple, extract services when you have evidence — not assumptions
- The best architecture is the one your team can operate and debug at 2 AM
