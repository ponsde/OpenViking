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
    "agfs": { "backend": "local" }
  },
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
EOF

exec openviking-server
