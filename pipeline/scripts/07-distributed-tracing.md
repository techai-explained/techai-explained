---
title: "Distributed Tracing: Following a Request Across 12 Services"
duration: "9 minutes"
voice: "en-US-GuyNeural"
---

## [TITLE] Distributed Tracing: Following a Request Across 12 Services
One user clicks "Buy Now" — how do you follow that request through 12 microservices, 3 databases, and 2 message queues?

## [DIAGRAM] What Is a Distributed Trace?
```
User Request: POST /checkout
│
├─── API Gateway ─────────────────────── 12ms
│    ├─── Auth Service ───────────────── 8ms
│    ├─── Cart Service ───────────────── 45ms
│    │    ├─── Inventory Service ─────── 22ms
│    │    │    └─── DB Query ─────────── 15ms
│    │    └─── Pricing Service ───────── 18ms
│    ├─── Payment Service ────────────── 340ms
│    │    ├─── Fraud Detection ───────── 120ms
│    │    └─── Payment Gateway ───────── 210ms
│    ├─── Order Service ──────────────── 55ms
│    │    ├─── DB Write ──────────────── 12ms
│    │    └─── Notification Queue ────── 8ms
│    └─── Email Service (async) ──────── 230ms
│
Total: 485ms  |  Trace ID: 4bf92f3577b34da6
```
Each horizontal bar is a **span**. Together they form a **trace** — a complete picture of one request's journey.

## [BULLETS] Anatomy of a Span
- **Trace ID** — Unique identifier shared by every span in the trace
- **Span ID** — Unique identifier for this specific operation
- **Parent Span ID** — Links child operations to their parent
- **Operation Name** — What this span represents (e.g., `HTTP GET /users`)
- **Start Time + Duration** — Exactly when it ran and how long it took
- **Tags / Attributes** — Key-value metadata (HTTP status, DB query, user ID)
- **Events / Logs** — Timestamped annotations within the span
- **Status** — OK, ERROR, or UNSET

## [DIAGRAM] Trace Context Propagation
```
┌──────────────┐  HTTP Header:                ┌──────────────┐
│  Service A   │  traceparent:                 │  Service B   │
│              │  00-4bf92f35...-001a-01       │              │
│  Span: 001a  │─────────────────────────────▶│  Span: 002b  │
│              │  Also propagated via:         │  Parent: 001a│
└──────────────┘  - gRPC metadata              └──────┬───────┘
                  - Message queue headers             │
                  - Baggage items              ┌──────▼───────┐
                                               │  Service C   │
W3C Trace Context Standard:                   │  Span: 003c  │
traceparent: {version}-{trace-id}-             │  Parent: 002b│
              {parent-id}-{flags}              └──────────────┘

Every service extracts the context, creates a child span,
and injects the context into outgoing requests.
```

## [CODE] OpenTelemetry Auto-Instrumentation
```python
# Install: pip install opentelemetry-api opentelemetry-sdk
#          opentelemetry-instrumentation-flask
#          opentelemetry-instrumentation-requests

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
    OTLPSpanExporter,
)
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Setup — runs once at application start
provider = TracerProvider()
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="otel-collector:4317"))
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

# Auto-instrument frameworks — zero code changes needed
FlaskInstrumentor().instrument()
RequestsInstrumentor().instrument()
```

## [CODE] Adding Custom Spans for Business Logic
```python
tracer = trace.get_tracer("checkout-service")

@app.route("/checkout", methods=["POST"])
def checkout():
    with tracer.start_as_current_span("validate_cart") as span:
        span.set_attribute("cart.item_count", len(cart_items))
        validate(cart_items)

    with tracer.start_as_current_span("process_payment") as span:
        span.set_attribute("payment.method", payment_method)
        span.set_attribute("payment.amount", total_amount)
        try:
            result = charge(payment_method, total_amount)
            span.set_attribute("payment.transaction_id", result.id)
        except PaymentError as e:
            span.set_status(StatusCode.ERROR, str(e))
            span.record_exception(e)
            raise

    with tracer.start_as_current_span("create_order") as span:
        order = create_order(cart_items, result.id)
        span.set_attribute("order.id", order.id)

    return {"order_id": order.id}
```

## [DIAGRAM] Using Traces to Debug an Incident
```
🔴 Alert: P95 latency spike on /checkout — 4200ms (normal: 500ms)

Step 1: Find slow traces
  └─▶ Filter: duration > 3000ms, last 30 minutes

Step 2: Open the trace waterfall
  ┌─ API Gateway ──────────────────────────── 15ms  ✅
  ├─ Auth Service ─────────────────────────── 10ms  ✅
  ├─ Cart Service ─────────────────────────── 40ms  ✅
  ├─ Payment Service ──────────────────────── 3800ms 🔴
  │  ├─ Fraud Detection ───────────────────── 3600ms 🔴
  │  │  └─ ML Model Inference ─────────────── 3580ms 🔴
  │  └─ Payment Gateway ───────────────────── 180ms  ✅
  └─ Order Service ────────────────────────── 50ms   ✅

Step 3: Root cause identified!
  └─▶ ML model inference spiked — model server was OOM
  └─▶ Fix: Scale fraud-detection pods, add timeout
```

## [BULLETS] Sampling Strategies
- **Head-based sampling** — Decide at trace start; simple but misses rare errors
- **Tail-based sampling** — Decide after trace completes; keeps errors and slow traces
- **Probabilistic** — Keep a fixed percentage (e.g., 10% of all traces)
- **Rate-limiting** — Keep N traces per second per service
- **Rule-based** — Always sample errors, health checks never, specific endpoints always
- **Adaptive** — Dynamically adjust rate based on traffic volume

## [COMPARISON] Jaeger vs Grafana Tempo
| Feature              | Jaeger                   | Grafana Tempo             |
|----------------------|--------------------------|---------------------------|
| Storage backend      | Elasticsearch, Cassandra | Object storage (S3, GCS)  |
| Cost at scale        | Higher (indexing)        | Lower (no indexing)       |
| Query speed          | Fast (indexed)           | Slower (scan-based)       |
| Search by attributes | Full search              | TraceQL + Exemplars       |
| Setup complexity     | Moderate                 | Simple with Grafana       |
| Metrics integration  | Separate                 | Native with Grafana stack |
| Service graph        | Built-in                 | Via Tempo + Grafana       |
| Open source          | ✅ CNCF Graduated        | ✅ AGPLv3                 |

## [BULLETS] Best Practices for Production Tracing
- **Instrument at the framework level first** — auto-instrumentation covers 80% of needs
- **Add custom spans for business operations** — not just HTTP calls
- **Always propagate context** — including through message queues and async workers
- **Use semantic conventions** — follow OpenTelemetry naming standards
- **Set meaningful span names** — `POST /api/users` not `HttpHandler`
- **Add error details** — record exceptions with stack traces on error spans
- **Correlate with logs and metrics** — use trace ID in log lines

## [CODE] Connecting Traces to Logs
```python
import logging
from opentelemetry import trace

# Add trace context to every log line
class TraceContextFilter(logging.Filter):
    def filter(self, record):
        ctx = trace.get_current_span().get_span_context()
        record.trace_id = format(ctx.trace_id, '032x') if ctx.trace_id else "N/A"
        record.span_id = format(ctx.span_id, '016x') if ctx.span_id else "N/A"
        return True

logger = logging.getLogger(__name__)
logger.addFilter(TraceContextFilter())
formatter = logging.Formatter(
    '%(asctime)s [trace=%(trace_id)s span=%(span_id)s] %(message)s'
)
# Output: 2026-01-15 10:23:45 [trace=4bf92f35... span=001a...] Payment processed
```

## [QUOTE] Key Takeaway
"Logs tell you what happened. Metrics tell you how much. Traces tell you WHY. In a microservices world, distributed tracing is how you turn a wall of alerts into an actionable story."

## [BULLETS] Getting Started Checklist
- Install the OpenTelemetry SDK for your language
- Enable auto-instrumentation for your web framework and HTTP client
- Deploy an OpenTelemetry Collector to receive and export spans
- Choose a backend: Jaeger for search, Tempo for cost-efficient storage
- Add trace IDs to your structured logs
- Start with 100% sampling in dev, then tune for production
