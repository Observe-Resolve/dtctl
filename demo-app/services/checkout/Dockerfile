FROM python:3.12-slim AS base

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY demo.proto demo_pb2.py demo_pb2_grpc.py main.py ./

# APP_VERSION is baked in at build time (the release.yml pipeline passes
# --build-arg APP_VERSION=$TAG). Falls back to a dev marker for local builds.
ARG APP_VERSION=v0.0.0-dev
ENV APP_VERSION=${APP_VERSION}

# gRPC on 8080, health HTTP on 8081
EXPOSE 8080 8081

CMD ["python", "main.py"]
