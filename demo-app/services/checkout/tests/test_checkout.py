"""
Unit tests for the checkout service.

Two jobs:
  1. Smoke test that /checkout returns 200 and a sane payload.
  2. Catch attribute regressions early — assert that the place_order span
     emits the four required attributes from weaver/registry/checkout.yaml.

The CI workflow (.github/workflows/ci.yml) runs these on every PR. If a
developer renames a span attribute and forgets the registry, the
observability-watch workflow files a drift ticket; if they forget the
test, this file fails fast.
"""

from fastapi.testclient import TestClient
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

from main import app  # noqa: E402  — must come after tracer setup

client = TestClient(app)

REQUIRED_ATTRS = {
    "customer.tier",
    "payment.method",
    "order.total_usd",
    "checkout.outcome",
}


def _post_order(tier="enterprise", method="credit_card", total=129.99):
    return client.post(
        "/checkout",
        json={
            "customer_tier":  tier,
            "payment_method": method,
            "items": [{"product_id": "sku-1", "quantity": 2}],
            "total_usd": total,
        },
    )


def test_checkout_returns_success():
    r = _post_order()
    assert r.status_code == 200
    assert r.json()["status"] == "success"


def test_place_order_span_carries_required_attributes():
    _exporter.clear()
    _post_order()

    spans = {s.name: s for s in _exporter.get_finished_spans()}
    assert "checkout.place_order" in spans, \
        "checkout.place_order span must be emitted on every order"

    place_order = spans["checkout.place_order"]
    attrs = set(place_order.attributes.keys())

    missing = REQUIRED_ATTRS - attrs
    assert not missing, (
        f"checkout.place_order is missing required attributes {sorted(missing)}. "
        f"If the rename was intentional, update weaver/registry/checkout.yaml "
        f"and this test in the same PR."
    )


def test_payment_charge_span_emitted():
    _exporter.clear()
    _post_order()

    spans = {s.name: s for s in _exporter.get_finished_spans()}
    assert "payment.charge" in spans
    assert spans["payment.charge"].attributes.get("payment.outcome") == "success"
