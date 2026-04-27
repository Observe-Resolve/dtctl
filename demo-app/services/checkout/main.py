"""
Checkout service — Observe & Resolve Episode 9.

Replaces the upstream otel-demo-light `checkout` so we own the source code
and can edit span attributes for the on-camera scenarios:

  - Beat 1 patch: adds `checkout.cart.size` attribute
  - Beat 2 patch: renames `customer.tier` → `customerTier` (the drift the
    Copilot-style watcher catches and Claude resolves)
  - Beat 3 patch: injects 600ms latency on payment.charge to trip the SRG

Instrumentation pattern matches `weaver/registry/checkout.yaml`. Any change
to the attributes below MUST land in the same PR as a registry update or
the `observability-watch` workflow files a drift ticket.
"""

import os
import time

from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from pydantic import BaseModel

# ─────────────────────────────────────────────────────────────────────────────
# OpenTelemetry — auto-instrumented via the Operator's Instrumentation CR;
# this code only declares the manual spans + attributes specific to checkout.
# ─────────────────────────────────────────────────────────────────────────────
tracer = trace.get_tracer("checkout")

app = FastAPI(title="checkout", version=os.environ.get("APP_VERSION", "v0.0.0-dev"))
FastAPIInstrumentor.instrument_app(app)
RequestsInstrumentor().instrument()


# ─────────────────────────────────────────────────────────────────────────────
# Request schema
# ─────────────────────────────────────────────────────────────────────────────
class LineItem(BaseModel):
    product_id: str
    quantity: int


class Order(BaseModel):
    customer_tier: str           # one of: free | plus | enterprise
    payment_method: str          # one of: credit_card | paypal | wallet
    items: list[LineItem]
    total_usd: float


# ─────────────────────────────────────────────────────────────────────────────
# Health endpoints
# ─────────────────────────────────────────────────────────────────────────────
@app.get("/healthz")
def healthz():
    return {"status": "ok", "version": app.version}


# ─────────────────────────────────────────────────────────────────────────────
# Place order — the only span the dashboard, the SLO, and the Guardian
# actually look at. Touch this method carefully.
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/checkout")
def place_order(order: Order):
    with tracer.start_as_current_span("checkout.place_order") as span:
        # ─── Required attributes per weaver/registry/checkout.yaml ───
        # Renaming any of these without a registry update WILL trip the
        # observability-watch GitHub Action and file a drift issue.
        span.set_attribute("customer.tier",  order.customer_tier)
        span.set_attribute("payment.method", order.payment_method)
        span.set_attribute("order.total_usd", order.total_usd)

        # ─── Recommended attributes (experimental in the registry) ───
        # Beat 1's add-cart-size patch inserts this line:
        # span.set_attribute("checkout.cart.size", len(order.items))

        # ─── Downstream call — also instrumented ───
        result = _charge(order)

        span.set_attribute("checkout.outcome", result["status"])
        return result


def _charge(order: Order) -> dict:
    with tracer.start_as_current_span("payment.charge") as span:
        span.set_attribute("payment.provider", "stripe")
        span.set_attribute("payment.amount_usd", order.total_usd)

        # Beat 3's inject-600ms-regression patch inserts a deliberate sleep here
        # to trip frontend-p95-latency + error-budget-burn objectives in the SRG.

        outcome = "success"  # in real life: provider_client.charge(...)
        span.set_attribute("payment.outcome", outcome)
        return {"status": outcome, "version": app.version}
