# api-omnivoice

OpenAI-compatible TTS API for `k2-fsa/OmniVoice` using `vLLM-Omni`.

Endpoint:

```text
POST /v1/audio/speech
```

## Important

`vllm-omni` is very sensitive to the installed `vllm` version.

This project pins:

```text
vllm==0.19.0
```

and installs `vllm-omni` with:

```bash
--no-deps
```

This avoids:

```text
ModuleNotFoundError: No module named 'vllm.inputs.data'
```

## Native install

```bash
cp .env.example .env
nano .env

chmod +x install.sh run.sh
./install.sh
source ./run.sh 0.0.0.0 8091
```

## Test health / models

```bash
curl http://127.0.0.1:8091/v1/models \
  -H "Authorization: Bearer change-me"
```

## Test TTS with curl

```bash
curl -X POST http://127.0.0.1:8091/v1/audio/speech \
  -H "Authorization: Bearer change-me" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "k2-fsa/OmniVoice",
    "input": "Bonjour, ceci est un test de synthèse vocale avec OmniVoice.",
    "voice": "default",
    "response_format": "wav"
  }' \
  --output output.wav
```

## Test TTS with OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8091/v1",
    api_key="change-me",
)

response = client.audio.speech.create(
    model="k2-fsa/OmniVoice",
    voice="default",
    input="Bonjour, ceci est un test.",
    response_format="wav",
)

response.stream_to_file("output.wav")
```

## Docker

```bash
cp .env.example .env
nano .env

chmod +x docker-run.sh
./docker-run.sh
```

## systemd example

```ini
[Unit]
Description=OmniVoice OpenAI-compatible TTS API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/api-tts-omnivoice
ExecStart=/bin/bash -lc 'source /opt/api-tts-omnivoice/run.sh 0.0.0.0 8091'
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

## H100 / DGX Spark notes

Start conservative:

```bash
GPU_MEMORY_UTILIZATION=0.50
DTYPE=float16
MAX_MODEL_LEN=4096
```

If stable on H100:

```bash
GPU_MEMORY_UTILIZATION=0.70
```

If OOM on DGX Spark:

```bash
GPU_MEMORY_UTILIZATION=0.35
```

## Debug version mismatch

```bash
source ~/venv/api-tts-omnivoice/bin/activate

python - <<'PY'
import vllm, sys, pkgutil

print("vLLM:", vllm.__version__)
print("vLLM path:", vllm.__file__)
print("Python:", sys.executable)

import vllm.inputs
print("vllm.inputs path:", vllm.inputs.__file__)
print("vllm.inputs modules:", [m.name for m in pkgutil.iter_modules(vllm.inputs.__path__)])

from vllm.inputs.data import TokensPrompt
print("OK: TokensPrompt")

import vllm_omni
print("OK: vLLM-Omni")
PY
```
