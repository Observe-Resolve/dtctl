# checkout — service source

Vendored Python gRPC implementation of the `CheckoutService`, compatible with the upstream [opentelemetry-demo](https://github.com/open-telemetry/opentelemetry-demo) protocol. We own this code (instead of pulling from upstream) so the on-camera scenarios can edit it freely:

- **Beat 1** patches in `checkout.cart.size` as a new span attribute
- **Beat 2** renames `customer.tier` → `customerTier` (the drift the watcher catches)
- **Beat 3** injects 600ms of latency on `payment.charge` (the regression the SRG blocks)

## Files

```
demo-app/services/checkout/
├── README.md                  # this file
├── main.py                    # gRPC server + manual OTel instrumentation
├── demo.proto                 # protobuf service definition (subset of otel-demo)
├── demo_pb2.py                # generated protobuf stubs
├── demo_pb2_grpc.py           # generated gRPC stubs
├── requirements.txt           # runtime deps (grpcio, protobuf, OTel SDK)
├── requirements-test.txt      # adds pytest
├── Dockerfile                 # python:3.12-slim, ARG APP_VERSION
├── tests/
│   └── test_checkout.py       # asserts required span attributes
├── patches/
│   ├── add-cart-size.sh           # Beat 1
│   ├── rename-customer-tier.sh    # Beat 2
│   └── inject-600ms-regression.sh # Beat 3
└── fetch-upstream.sh          # OPTIONAL — clones opentelemetry-demo-light
```

## Spans this service emits

| Span name | Required attributes |
|---|---|
| `oteldemo.CheckoutService/PlaceOrder` | `customer.tier`, `payment.method`, `order.total_usd`, `checkout.outcome` |
| `payment.charge` | `payment.provider`, `payment.amount_usd`, `payment.outcome` |

These match `weaver/registry/checkout.yaml`. Renaming any required attribute without a registry update will trip `observability-watch` in CI.

## Build locally

```bash
cd demo-app/services/checkout
docker build --build-arg APP_VERSION=1.0.2-local -t ghcr.io/observe-resolve/checkout:1.0.2-local .
```

`release.yml` does the same in CI on every git tag, with `APP_VERSION=$TAG`.

## Run locally for testing

```bash
cd demo-app/services/checkout
pip install -r requirements-test.txt
python main.py
# The gRPC server listens on port 8080, health HTTP on port 8081
```

## Run the tests

```bash
cd demo-app/services/checkout
pip install -r requirements-test.txt
pytest tests/ -v
```

CI runs this on every PR (see `.github/workflows/ci.yml`). The tests assert that `oteldemo.CheckoutService/PlaceOrder` carries all required attributes — so a developer who renames an attribute without updating the test fails fast (the registry-drift watcher fires next).

## Regenerating protobuf stubs

If you update `demo.proto`, regenerate the stubs with matching protobuf versions:

```bash
python -m venv /tmp/protoc-venv
source /tmp/protoc-venv/bin/activate
pip install grpcio-tools==1.68.1 protobuf==5.29.2
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. demo.proto
deactivate
```

The pinned versions must match `requirements.txt` to avoid runtime version mismatches.

## Why we vendor instead of submodule

A submodule would couple us to the upstream's directory layout and language. The on-camera demo needs:

1. Editable source (the rename has to be a real `git diff`).
2. A reproducible Docker build (the `release.yml` pipeline pushes `ghcr.io/observe-resolve/checkout:$TAG`).
3. Stable patch anchor points so the scenario scripts don't break when upstream refactors.

Vendoring gives us all three; the trade-off is we re-pull from upstream manually when there's something worth syncing.
