# syntax=docker/dockerfile:1.9

# Stage 1: provide Go toolchain (required by setup.py -> build_agfs_artifacts -> make build)
FROM golang:1.26-trixie AS go-toolchain

# Stage 2: provide Rust toolchain (required by setup.py -> build_ov_cli_artifact -> cargo build)
FROM rust:1.88-trixie AS rust-toolchain

# Stage 3: build Python environment with uv (builds AGFS + Rust CLI + C++ extension from source)
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

# Build ragfs-python (Rust AGFS binding).
COPY <<'EXTRACT_SCRIPT' /tmp/extract_ragfs.py
import zipfile, glob, os, sys
tmpdir, ov_lib = os.environ['_TMPDIR'], os.environ['_OV_LIB']
whls = glob.glob(os.path.join(tmpdir, 'ragfs_python-*.whl'))
assert whls, 'maturin produced no wheel'
with zipfile.ZipFile(whls[0]) as zf:
    for name in zf.namelist():
        bn = os.path.basename(name)
        if bn.startswith('ragfs_python') and (bn.endswith('.so') or bn.endswith('.pyd')):
            dst = os.path.join(ov_lib, bn)
            with zf.open(name) as src, open(dst, 'wb') as f:
                f.write(src.read())
            os.chmod(dst, 0o755)
            print(f'ragfs-python: extracted {bn} -> {dst}')
            sys.exit(0)
print('WARNING: No ragfs_python .so/.pyd in wheel')
sys.exit(1)
EXTRACT_SCRIPT
RUN uv pip install maturin && \
    export PATH="/app/.venv/bin:$PATH" && \
    export _TMPDIR=$(mktemp -d) && \
    cd crates/ragfs-python && \
    maturin build --release --out "$_TMPDIR" && \
    cd ../.. && \
    export _OV_LIB=$(/app/.venv/bin/python -c "import openviking; from pathlib import Path; print(Path(openviking.__file__).resolve().parent / 'lib')") && \
    mkdir -p "$_OV_LIB" && \
    /app/.venv/bin/python /tmp/extract_ragfs.py && \
    rm -rf "$_TMPDIR" /tmp/extract_ragfs.py

# Stage 4: runtime (backend only)
FROM python:3.13-slim-trixie

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libstdc++6 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=py-builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"
ENV OPENVIKING_CONFIG_FILE="/app/ov.conf"

# Entrypoint script: generate ov.conf from env vars at runtime, then start server
COPY <<'START_SCRIPT' /usr/local/bin/start.sh
#!/bin/sh
set -eu

cat > /app/ov.conf <<EOF
{
  "server": {
    "host": "0.0.0.0",
    "port": 1933,
    "root_api_key": "${OV_ROOT_API_KEY:-ov-demo-key}",
    "cors_origins": ["*"]
  },
  "storage": {
    "workspace": "/app/data",
    "vectordb": { "backend": "local" },
    "agfs": { "backend": "local" },
    "embedding": {
      "dense": {
        "provider": "${OV_EMBED_PROVIDER:-openai}",
        "model": "${OV_EMBED_MODEL:-text-embedding-3-small}",
        "api_key": "${OV_EMBED_API_KEY:-}",
        "api_base": "${OV_EMBED_API_BASE:-https://api.openai.com/v1}",
        "dimension": ${OV_EMBED_DIMENSION:-1536}
      }
    }
  }
}
EOF

exec openviking-server
START_SCRIPT
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 1933

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:1933/health || exit 1

CMD ["start.sh"]
