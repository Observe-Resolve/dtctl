"""
Unit tests for the checkout gRPC service.

Two jobs:
  1. Smoke test that PlaceOrder returns a valid response.
  2. Catch attribute regressions early — assert that the PlaceOrder span
     emits the required attributes from weaver/registry/checkout.yaml.

The CI workflow (.github/workflows/ci.yml) runs these on every PR. If a
developer renames a span attribute and forgets the registry, the
observability-watch workflow files a drift ticket; if they forget the
test, this file fails fast.
"""

import grpc
from concurrent import futures

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import (
    InMemorySpanExporter,
)

# Set up an in-memory exporter BEFORE importing the app so the manual
# spans land in our buffer instead of /dev/null.
_exporter = InMemorySpanExporter()
_provider = TracerProvider()
_provider.add_span_processor(SimpleSpanProcessor(_exporter))
trace.set_tracer_provider(_provider)

import demo_pb2
import demo_pb2_grpc
from main import CheckoutServicer  # noqa: E402 — must come after tracer setup

REQUIRED_ATTRS = {
    "customer.tier",
    "payment.method",
    "order.total_usd",
    "checkout.outcome",
}


def _make_request(user_id="user-42", currency="USD", email="test@example.com"):
    return demo_pb2.PlaceOrderRequest(
        user_id=user_id,
        user_currency=currency,
        email=email,
        address=demo_pb2.Address(
            street_address="123 Main St",
            city="Springfield",
            state="IL",
            country="US",
            zip_code="62701",
        ),
        credit_card=demo_pb2.CreditCardInfo(
            credit_card_number="4111111111111111",
            credit_card_cvv=123,
            credit_card_expiration_year=2030,
            credit_card_expiration_month=12,
        ),
    )


def _call_place_order(request=None):
    """Call PlaceOrder directly on the servicer (no network needed)."""
    servicer = CheckoutServicer()
    if request is None:
        request = _make_request()
    return servicer.PlaceOrder(request, context=None)


def test_place_order_returns_order():
    response = _call_place_order()
    assert response.order.order_id, "order_id must be set"
    assert response.order.shipping_tracking_id, "shipping_tracking_id must be set"


def test_place_order_span_carries_required_attributes():
    _exporter.clear()
    _call_place_order()

    spans = {s.name: s for s in _exporter.get_finished_spans()}
    assert "oteldemo.CheckoutService/PlaceOrder" in spans, \
        "oteldemo.CheckoutService/PlaceOrder span must be emitted on every order"

    place_order = spans["oteldemo.CheckoutService/PlaceOrder"]
    attrs = set(place_order.attributes.keys())

    missing = REQUIRED_ATTRS - attrs
    assert not missing, (
        f"PlaceOrder span is missing required attributes {sorted(missing)}. "
        f"If the rename was intentional, update weaver/registry/checkout.yaml "
        f"and this test in the same PR."
    )


def test_payment_charge_span_emitted():
    _exporter.clear()
    _call_place_order()

    spans = {s.name: s for s in _exporter.get_finished_spans()}
    assert "payment.charge" in spans
    assert spans["payment.charge"].attributes.get("payment.outcome") == "success"
