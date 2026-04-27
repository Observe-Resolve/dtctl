# checkout — service source

Vendored Python FastAPI implementation of the `checkout` service. We own this code (instead of pulling from upstream `opentelemetry-demo-light`) so the on-camera scenarios can edit it freely:

- **Beat 1** patches in `checkout.cart.size` as a new span attribute
- **Beat 2** renames `customer.tier` → `customerTier` (the drift the watcher catches)
- **Beat 3** injects 600ms of latency on `payment.charge` (the regression the SRG blocks)

## Files

```
demo-app/services/checkout/
├── README.md                  # this file
├── main.py                    # FastAPI app + OTel instrumentation (~80 lines)
├── requirements.txt           # runtime deps (FastAPI, uvicorn, OTel SDK)
├── requirements-test.txt      # adds pytest + httpx
├── Dockerfile                 # python:3.12-slim, ARG APP_VERSION
├── tests/
│   └── test_checkout.py       # asserts the four required span attributes
├── patches/
│   ├── add-cart-size.sh           # Beat 1
│   ├── rename-customer-tier.sh    # Beat 2
│   └── inject-600ms-regression.sh # Beat 3
└── fetch-upstream.sh          # OPTIONAL — clones opentelemetry-demo-light
```

## Spans this service emits

| Span name | Required attributes |
|---|---|
| `checkout.place_order` | `customer.tier`, `payment.method`, `order.total_usd`, `checkout.outcome` |
| `payment.charge` | `payment.provider`, `payment.amount_usd`, `payment.outcome` |

These match `weaver/registry/checkout.yaml` and `weaver/registry/payment.yaml`. Renaming any required attribute without a registry update will trip `observability-watch` in CI.

## Build locally

```bash
cd demo-app/services/checkout
docker build --build-arg APP_VERSION=v1.0.0-local -t ghcr.io/henrikrexed/checkout:v1.0.0-local .
```

`release.yml` does the same in CI on every git tag, with `APP_VERSION=$TAG`.

## Run locally for testing

```bash
cd demo-app/services/checkout
pip install -r requirements-test.txt
APP_VERSION=v1.0.0-local uvicorn main:app --reload --port 8080
# Then in another terminal:
curl -X POST http://localhost:8080/checkout \
    -H 'Content-Type: application/json' \
    -d '{"customer_tier":"enterprise","payment_method":"credit_card","items":[{"product_id":"sku-1","quantity":2}],"total_usd":129.99}'
```

## Run the tests

```bash
cd demo-app/services/checkout
pip install -r requirements-test.txt
pytest tests/ -v
```

CI runs this on every PR (see `.github/workflows/ci.yml`). The tests assert that `checkout.place_order` carries all four required attributes — so a developer who renames an attribute without updating the test fails fast (the registry-drift watcher fires next).

## Want to start from upstream instead?

Run:

```bash
./demo-app/services/checkout/fetch-upstream.sh
```

It clones `henrikrexed/opentelemetry-demo-light` to `_upstream/repo/`, locates the upstream checkout source, and prints next-step instructions. Note: upstream `checkout` is in Go — adopting it means rewriting `Dockerfile`, `tests/`, and the three `patches/*.sh` for Go syntax.

## Why we vendor instead of submodule

A submodule would couple us to the upstream's directory layout and language. The on-camera demo needs:

1. Editable source (the rename has to be a real `git diff`).
2. A reproducible Docker build (the `release.yml` pipeline pushes `ghcr.io/henrikrexed/checkout:$TAG`).
3. Stable patch anchor points so the scenario scripts don't break when upstream refactors.

Vendoring gives us all three; the trade-off is we re-pull from upstream manually when there's something worth syncing.
