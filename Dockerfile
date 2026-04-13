# syntax=docker/dockerfile:1.9

# Stage 1: provide Rust toolchain (required by setup.py -> build_ov_cli_artifact -> cargo build)
FROM rust:1.88-trixie AS rust-toolchain

# Stage 2: build Python environment with uv (builds Rust CLI + C++ extension from source)
FROM ghcr.io/astral-sh/uv:python3.13-trixie-slim AS py-builder

# Reuse Rust toolchain from stage 1 so setup.py can compile ov CLI in-place.
COPY --from=rust-toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust-toolchain /usr/local/rustup /usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH="/app/.venv/bin:/usr/local/cargo/bin:${PATH}"
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
COPY pyproject.toml uv.lock setup.py MANIFEST.in README.md ./
COPY build_support/ build_support/
COPY bot/ bot/
COPY crates/ crates/
COPY openviking/ openviking/
COPY openviking_cli/ openviking_cli/
COPY src/ src/
# Vendored C++ dependencies (spdlog, leveldb, croaring, rapidjson) required by
# src/CMakeLists.txt via add_subdirectory(../third_party/...). Missing this
# COPY breaks the setuptools C++ extension build with:
#   CMake Error at CMakeLists.txt:70 (add_subdirectory):
#     add_subdirectory given source "../third_party/spdlog-1.14.1" which
#     is not an existing directory.
COPY third_party/ third_party/

# Install project and dependencies (triggers setup.py artifact builds + build_extension).
# OV_SKIP_RAGFS_BUILD=1 tells setup.py to skip the in-tree ragfs-python maturin
# build; we do that in a dedicated RUN step below where PATH/env is reliable.
# Without this, uv sync would attempt the maturin build inside its build-isolation
# env (where the Rust toolchain/env may not match) and fail.
RUN case "${UV_LOCK_STRATEGY}" in \
        locked) \
            OV_SKIP_RAGFS_BUILD=1 uv sync --locked --no-editable --extra bot --extra gemini \
            ;; \
        auto) \
            if ! uv lock --check; then \
                uv lock; \
            fi; \
            OV_SKIP_RAGFS_BUILD=1 uv sync --locked --no-editable --extra bot --extra gemini \
            ;; \
        *) \
            echo "Unsupported UV_LOCK_STRATEGY: ${UV_LOCK_STRATEGY}" >&2; \
            exit 2 \
            ;; \
    esac

# Build ragfs-python (Rust RAGFS binding) and extract the native extension
# into the installed openviking package.
# NOTE: Uses external docker/extract_ragfs.py (instead of heredoc) and omits
# the uv cache mount — both are required for Railway's Docker builder which
# does not support those syntaxes.
COPY docker/extract_ragfs.py /tmp/extract_ragfs.py
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

# Stage 3: runtime (backend only)
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
COPY docker/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 1933

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:1933/health || exit 1

CMD ["start.sh"]
