"""
Checkout service — Observe & Resolve Episode 9.

gRPC server implementing oteldemo.CheckoutService/PlaceOrder, compatible with
the upstream otel-demo frontend and load generator.

100% manual OpenTelemetry instrumentation — no auto-injection. Every span and
attribute is created explicitly in this file. This is the code the on-camera
scenarios modify:

  - Beat 1 patch: adds `checkout.cart.size` attribute
  - Beat 2 patch: renames `customer.tier` → `customerTier` (drift scenario)
  - Beat 3 patch: injects 600ms latency on payment.charge to trip the SRG

Instrumentation pattern matches `weaver/registry/checkout.yaml`. Any change
to the attributes below MUST land in the same PR as a registry update or
the `observability-watch` workflow files a drift ticket.
"""

import os
import uuid
import time
import logging
from concurrent import futures

import grpc

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes
from opentelemetry.instrumentation.grpc import (
    GrpcInstrumentorServer,
)

import demo_pb2
import demo_pb2_grpc

# ─────────────────────────────────────────────────────────────────────────────
# OpenTelemetry setup — fully manual, no Operator injection
# ─────────────────────────────────────────────────────────────────────────────
APP_VERSION = os.environ.get("APP_VERSION", "0.0.0-dev")
OTEL_SERVICE_NAME = os.environ.get("OTEL_SERVICE_NAME", "checkout")
OTEL_EXPORTER_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")

# Build resource attributes from env + explicit values
resource_attrs = {
    ResourceAttributes.SERVICE_NAME: OTEL_SERVICE_NAME,
    ResourceAttributes.SERVICE_VERSION: APP_VERSION,
}
# Parse OTEL_RESOURCE_ATTRIBUTES if set (key=value,key=value)
for pair in os.environ.get("OTEL_RESOURCE_ATTRIBUTES", "").split(","):
    if "=" in pair:
        k, v = pair.split("=", 1)
        resource_attrs[k.strip()] = v.strip()

resource = Resource.create(resource_attrs)
provider = TracerProvider(resource=resource)
exporter = OTLPSpanExporter(endpoint=OTEL_EXPORTER_ENDPOINT, insecure=True)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("checkout", APP_VERSION)

# Auto-instrument gRPC server calls (creates parent spans for each RPC)
GrpcInstrumentorServer().instrument()

logger = logging.getLogger("checkout")
logging.basicConfig(level=logging.INFO)


# ─────────────────────────────────────────────────────────────────────────────
# CheckoutService implementation
# ─────────────────────────────────────────────────────────────────────────────
class CheckoutServicer(demo_pb2_grpc.CheckoutServiceServicer):
    """Implements oteldemo.CheckoutService/PlaceOrder with manual OTel spans."""

    def PlaceOrder(self, request, context):
        with tracer.start_as_current_span("oteldemo.CheckoutService/PlaceOrder") as span:
            # ─── Required attributes per weaver/registry/checkout.yaml ───
            # Renaming any of these without a registry update WILL trip the
            # observability-watch GitHub Action and file a drift issue.
            span.set_attribute("customer.tier", _infer_customer_tier(request.user_id))
            span.set_attribute("payment.method", _infer_payment_method(request.credit_card))
            span.set_attribute("order.total_usd", _calculate_total(request))

            # ─── Recommended attributes (experimental in the registry) ───
            # Beat 1's add-cart-size patch inserts this line:
            # span.set_attribute("checkout.cart.size", len(request_items))

            span.set_attribute("app.user_id", request.user_id)
            span.set_attribute("app.user_currency", request.user_currency)

            # ─── Downstream call — also instrumented ───
            transaction_id = _charge(request)

            order_id = str(uuid.uuid4())
            span.set_attribute("checkout.outcome", "success")
            span.set_attribute("app.order.id", order_id)

            # Build response matching the proto
            order_result = demo_pb2.OrderResult(
                order_id=order_id,
                shipping_tracking_id=str(uuid.uuid4()),
                shipping_cost=demo_pb2.Money(
                    currency_code=request.user_currency or "USD",
                    units=5,
                    nanos=990000000,
                ),
                shipping_address=request.address,
                items=[
                    demo_pb2.OrderItem(
                        item=demo_pb2.CartItem(product_id="demo-product", quantity=1),
                        cost=demo_pb2.Money(currency_code=request.user_currency or "USD", units=10, nanos=0),
                    )
                ],
            )

            logger.info("order %s placed successfully (tx: %s)", order_id, transaction_id)
            return demo_pb2.PlaceOrderResponse(order=order_result)


def _charge(request) -> str:
    """Simulate a payment charge with manual OTel span."""
    with tracer.start_as_current_span("payment.charge") as span:
        span.set_attribute("payment.provider", "stripe")
        span.set_attribute("payment.amount_usd", _calculate_total(request))

        # Beat 3's inject-600ms-regression patch inserts a deliberate sleep here
        # to trip frontend-p95-latency + error-budget-burn objectives in the SRG.

        transaction_id = str(uuid.uuid4())
        span.set_attribute("payment.outcome", "success")
        span.set_attribute("payment.transaction_id", transaction_id)
        return transaction_id


def _infer_customer_tier(user_id: str) -> str:
    """Derive a tier from user_id for demo purposes."""
    if not user_id:
        return "free"
    h = hash(user_id) % 100
    if h < 60:
        return "free"
    elif h < 90:
        return "plus"
    return "enterprise"


def _infer_payment_method(credit_card) -> str:
    """Derive payment method from the request."""
    if credit_card and credit_card.credit_card_number:
        return "credit_card"
    return "wallet"


def _calculate_total(request) -> float:
    """Return a dummy total for demo purposes."""
    return 42.99


# ─────────────────────────────────────────────────────────────────────────────
# Health check via gRPC reflection or a simple HTTP endpoint
# ─────────────────────────────────────────────────────────────────────────────
def _serve_health_http():
    """Minimal HTTP health endpoint on port 8081 for k8s probes."""
    import threading
    from http.server import HTTPServer, BaseHTTPRequestHandler

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/healthz":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(f'{{"status":"ok","version":"{APP_VERSION}"}}'.encode())
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, *args):
            pass  # suppress access logs

    server = HTTPServer(("0.0.0.0", 8081), Handler)
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    logger.info("health endpoint listening on :8081/healthz")


# ─────────────────────────────────────────────────────────────────────────────
# Server entry point
# ─────────────────────────────────────────────────────────────────────────────
def serve():
    port = os.environ.get("CHECKOUT_PORT", "8080")
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    demo_pb2_grpc.add_CheckoutServiceServicer_to_server(CheckoutServicer(), server)
    server.add_insecure_port(f"[::]:{port}")

    # Start HTTP health endpoint for k8s probes
    _serve_health_http()

    logger.info("checkout gRPC server listening on :%s (version %s)", port, APP_VERSION)
    server.start()
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
