#!/bin/sh
set -eu

python3 -c "
import json, os

config = {
    'server': {
        'host': '0.0.0.0',
        'port': 1933,
        'root_api_key': os.environ.get('OV_ROOT_API_KEY', 'ov-demo-key'),
        'cors_origins': ['*']
    },
    'storage': {
        'workspace': '/app/data',
        'vectordb': {'backend': 'local'},
        'agfs': {'backend': 'local'}
    },
    'embedding': {
        'dense': {
            'provider': os.environ.get('OV_EMBED_PROVIDER', 'openai'),
            'model': os.environ.get('OV_EMBED_MODEL', 'text-embedding-3-small'),
            'api_key': os.environ.get('OV_EMBED_API_KEY', ''),
            'api_base': os.environ.get('OV_EMBED_API_BASE', 'https://api.openai.com/v1'),
            'dimension': int(os.environ.get('OV_EMBED_DIMENSION', '1536'))
        }
    }
}

# VLM is optional: only add if OV_VLM_MODEL is set
vlm_model = os.environ.get('OV_VLM_MODEL', '')
if vlm_model:
    config['vlm'] = {
        'provider': os.environ.get('OV_VLM_PROVIDER', 'openai'),
        'model': vlm_model,
        'api_key': os.environ.get('OV_VLM_API_KEY', os.environ.get('OV_EMBED_API_KEY', '')),
        'api_base': os.environ.get('OV_VLM_API_BASE', os.environ.get('OV_EMBED_API_BASE', 'https://api.openai.com/v1'))
    }

with open('/app/ov.conf', 'w') as f:
    json.dump(config, f, indent=2)
"

exec openviking-server
