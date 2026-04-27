FROM python:3.12-slim AS base

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# APP_VERSION is baked in at build time (the release.yml pipeline passes
# --build-arg APP_VERSION=$TAG). Falls back to a dev marker for local builds.
ARG APP_VERSION=v0.0.0-dev
ENV APP_VERSION=${APP_VERSION}

EXPOSE 8080

# uvicorn flags chosen for low overhead on a 2x8GB cluster:
#   --workers 1     keeps memory predictable; the Rollout scales horizontally
#   --no-access-log silences hot-path logging; spans carry the same info
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", \
     "--workers", "1", "--no-access-log"]
