# syntax=docker/dockerfile:1.9

# Stage 1: provide Go toolchain (required by setup.py -> build_agfs_artifacts -> make build)
FROM golang:1.26-trixie AS go-toolchain

# Stage 2: provide Rust toolchain (required by setup.py -> build_ov_cli_artifact -> cargo build)
FROM rust:1.88-trixie AS rust-toolchain

# Stage 3: build web-studio frontend
FROM node:22-alpine AS frontend-builder
WORKDIR /frontend
COPY web-studio/package.json web-studio/package-lock.json ./
RUN npm ci
COPY web-studio/ .
RUN npm run build

# Stage 4: build Python environment with uv (builds AGFS + Rust CLI + C++ extension from source)
FROM ghcr.io/astral-sh/uv:python3.13-trixie-slim AS py-builder

# Reuse Go toolchain from stage 1 so setup.py can compile agfs-server in-place.
COPY --from=go-toolchain /usr/local/go /usr/local/go
# Reuse Rust toolchain from stage 2 so setup.py can compile ov CLI in-place.
COPY --from=rust-toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust-toolchain /usr/local/rustup /usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH="/usr/local/cargo/bin:/usr/local/go/bin:${PATH}"
ARG OPENVIKING_VERSION=0.0.0
ARG TARGETPLATFORM
ARG UV_LOCK_STRATEGY=auto
ENV SETUPTOOLS_SCM_PRETEND_VERSION_FOR_OPENVIKING=${OPENVIKING_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
 && rm -rf /var/lib/apt/lists/*

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_NO_DEV=1
WORKDIR /app

# Copy source required for setup.py artifact builds and native extension build.
COPY Cargo.toml Cargo.lock ./
COPY pyproject.toml uv.lock setup.py README.md ./
COPY build_support/ build_support/
COPY bot/ bot/
COPY crates/ crates/
COPY openviking/ openviking/
COPY openviking_cli/ openviking_cli/
COPY src/ src/
COPY third_party/ third_party/

# Install project and dependencies (triggers setup.py artifact builds + build_extension).
# Default to auto-refreshing uv.lock inside the ephemeral build context when it is
# stale, so Docker builds stay unblocked after dependency changes. Set
# UV_LOCK_STRATEGY=locked to keep fail-fast reproducibility checks.
RUN case "${UV_LOCK_STRATEGY}" in \
        locked) \
            uv sync --locked --no-editable --extra bot \
            ;; \
        auto) \
            if ! uv lock --check; then \
                uv lock; \
            fi; \
            uv sync --locked --no-editable --extra bot \
            ;; \
        *) \
            echo "Unsupported UV_LOCK_STRATEGY: ${UV_LOCK_STRATEGY}" >&2; \
            exit 2 \
            ;; \
    esac

# Stage 5: runtime (backend + frontend via nginx)
FROM python:3.13-slim-trixie

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libstdc++6 \
    nginx \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=py-builder /app/.venv /app/.venv
COPY --from=frontend-builder /frontend/dist /app/frontend
COPY docker/openviking-console-entrypoint.sh /usr/local/bin/openviking-console-entrypoint
RUN chmod +x /usr/local/bin/openviking-console-entrypoint
ENV PATH="/app/.venv/bin:$PATH"
ENV OPENVIKING_CONFIG_FILE="/app/ov.conf"

# Create minimal config for Railway/cloud deployment.
RUN printf '{\n\
  "server": {\n\
    "host": "127.0.0.1",\n\
    "port": 1933,\n\
    "root_api_key": "ov-demo-key-change-me"\n\
  },\n\
  "storage": {\n\
    "workspace": "/app/data",\n\
    "vectordb": { "backend": "local" },\n\
    "agfs": { "backend": "local" }\n\
  }\n\
}\n' > /app/ov.conf

# Nginx config: serve frontend on port 8080, proxy /api and /bot to backend
RUN cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 8080;
    root /app/frontend;
    index index.html;

    # Frontend SPA - all non-API routes serve index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to OV backend
    location /api/ {
        proxy_pass http://127.0.0.1:1933;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300s;
    }

    location /bot/ {
        proxy_pass http://127.0.0.1:1933;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300s;
        proxy_buffering off;
    }

    location /health {
        proxy_pass http://127.0.0.1:1933;
    }

    location /ready {
        proxy_pass http://127.0.0.1:1933;
    }

    location /docs {
        proxy_pass http://127.0.0.1:1933;
    }

    location /openapi.json {
        proxy_pass http://127.0.0.1:1933;
    }

    location /metrics {
        proxy_pass http://127.0.0.1:1933;
    }
}
NGINX

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:1933/health || exit 1

# Custom entrypoint: start backend + nginx
COPY <<'ENTRYPOINT_SCRIPT' /usr/local/bin/start.sh
#!/bin/sh
set -eu

# Start OV backend
openviking-server &
SERVER_PID=$!

# Wait for backend to be healthy
attempt=0
until curl -fsS http://127.0.0.1:1933/health >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[start] openviking-server exited before becoming healthy" >&2
        exit 1
    fi
    if [ "$attempt" -ge 120 ]; then
        echo "[start] timed out waiting for backend" >&2
        kill "$SERVER_PID" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

echo "[start] Backend healthy, starting nginx on port 8080"
nginx -g 'daemon off;' &
NGINX_PID=$!

# Wait for either to exit
trap 'kill $SERVER_PID $NGINX_PID 2>/dev/null; exit 0' INT TERM
wait -n "$SERVER_PID" "$NGINX_PID" || true
kill "$SERVER_PID" "$NGINX_PID" 2>/dev/null || true
wait
ENTRYPOINT_SCRIPT
RUN chmod +x /usr/local/bin/start.sh

ENTRYPOINT ["start.sh"]
