#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="$(basename "$APP_DIR")"

if [[ -f "$APP_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$APP_DIR/.env"
  set +a
fi

HOST="${1:-${HOST:-0.0.0.0}}"
PORT="${2:-${PORT:-8091}}"

VENV_DIR="${VENV_DIR:-$HOME/venv/$APP_NAME}"

MODEL_ID="${MODEL_ID:-k2-fsa/OmniVoice}"
API_KEY="${API_KEY:-}"

# Static voice-clone mode (non-API): when enabled, a local reference audio
# is loaded by custom runtimes that support speaker conditioning.
CLONE_MODE="${CLONE_MODE:-0}"
REFERENCE_AUDIO_PATH="${REFERENCE_AUDIO_PATH:-}"

HF_HOME="${HF_HOME:-$APP_DIR/.cache/huggingface}"
CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.50}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"
DTYPE="${DTYPE:-float16}"
TRUST_REMOTE_CODE="${TRUST_REMOTE_CODE:-1}"

export HF_HOME
export CUDA_VISIBLE_DEVICES
export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"
export PYTHONUNBUFFERED=1
export CLONE_MODE
export REFERENCE_AUDIO_PATH

if [[ "$CLONE_MODE" == "1" || "$CLONE_MODE" == "true" ]]; then
  if [[ -z "$REFERENCE_AUDIO_PATH" ]]; then
    echo "ERROR: CLONE_MODE is enabled but REFERENCE_AUDIO_PATH is empty." >&2
    echo "Set REFERENCE_AUDIO_PATH to a local WAV file (e.g. /opt/voices/default.wav)." >&2
    exit 1
  fi
  if [[ ! -f "$REFERENCE_AUDIO_PATH" ]]; then
    echo "ERROR: REFERENCE_AUDIO_PATH does not exist: $REFERENCE_AUDIO_PATH" >&2
    exit 1
  fi
fi

if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
  echo "ERROR: Virtual environment not found at $VENV_DIR" >&2
  echo "Run ./install.sh successfully first, or set VENV_DIR to the correct environment." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

if ! command -v vllm >/dev/null 2>&1; then
  echo "ERROR: vllm CLI not found in the activated virtual environment: $VENV_DIR" >&2
  echo "The install likely did not complete. Run ./install.sh and check for errors before starting the API." >&2
  exit 127
fi

ARGS=(
  serve "$MODEL_ID"
  --host "$HOST"
  --port "$PORT"
  --omni
  --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION"
  --max-model-len "$MAX_MODEL_LEN"
  --dtype "$DTYPE"
)

if [[ "$TRUST_REMOTE_CODE" == "1" || "$TRUST_REMOTE_CODE" == "true" ]]; then
  ARGS+=(--trust-remote-code)
fi

if [[ -n "$API_KEY" ]]; then
  ARGS+=(--api-key "$API_KEY")
fi

echo "==> Starting OmniVoice OpenAI-compatible API"
echo "    URL:   http://${HOST}:${PORT}/v1/audio/speech"
echo "    Model: $MODEL_ID"
if [[ "$CLONE_MODE" == "1" || "$CLONE_MODE" == "true" ]]; then
  echo "    Clone: static reference enabled ($REFERENCE_AUDIO_PATH)"
else
  echo "    Clone: disabled"
fi
echo "    Venv:  $VENV_DIR"
echo "    GPU:   CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
echo

exec vllm "${ARGS[@]}"
