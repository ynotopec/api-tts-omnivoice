#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="$(basename "$APP_DIR")"
VENV_DIR="${VENV_DIR:-$HOME/venv/$APP_NAME}"

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

# Couple testé attendu :
# - vLLM-Omni v0.19.0rc1 est aligné avec upstream vLLM v0.19.0
# - le package PyPI peut être désaligné et provoquer :
#   ModuleNotFoundError: No module named 'vllm.inputs.data'
VLLM_VERSION="${VLLM_VERSION:-0.19.0}"
VLLM_OMNI_GIT_REF="${VLLM_OMNI_GIT_REF:-v0.19.0rc1}"

echo "==> App dir:        $APP_DIR"
echo "==> Venv:           $VENV_DIR"
echo "==> Python:         $PYTHON_VERSION"
echo "==> vLLM:           $VLLM_VERSION"
echo "==> vLLM-Omni ref:  $VLLM_OMNI_GIT_REF"

if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

mkdir -p "$(dirname "$VENV_DIR")"

echo "==> Installing Python $PYTHON_VERSION if needed..."
uv python install "$PYTHON_VERSION"

echo "==> Creating/upgrading venv..."
uv venv --clear --python "$PYTHON_VERSION" "$VENV_DIR"

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "==> Upgrading packaging tools..."
uv pip install -U pip setuptools wheel packaging ninja

echo "==> Removing possibly incompatible versions..."
uv pip uninstall vllm vllm-omni || true

# Detect CUDA version and select appropriate wheel
CUDART_PATH="$(ldconfig -p 2>/dev/null | grep 'libcudart.so.13' | head -1 | awk '{print $NF}')"
if [ -n "$CUDART_PATH" ] && [ -f "$CUDART_PATH" ]; then
  CUDA_TAG="cu130"
  echo "==> Detected CUDA 13.x, will install vLLM +cu130 wheel"
else
  CUDA_TAG="auto"
  echo "==> No CUDA 13 detected, installing vLLM with default backend"
fi

echo "==> Installing vLLM pinned version..."
if [ "$CUDA_TAG" = "auto" ]; then
  uv pip install --reinstall "vllm==${VLLM_VERSION}" --torch-backend=auto
else
  CPU_ARCH="$(uname -m)"
  VLLM_WHEEL_URL="https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+${CUDA_TAG}-cp38-abi3-manylinux_2_35_${CPU_ARCH}.whl"
  echo "==> Downloading vLLM wheel: ${VLLM_WHEEL_URL}"
  uv pip install --reinstall "${VLLM_WHEEL_URL}"
fi

# Ensure PyTorch matches the CUDA version for vLLM cu130 wheels
if [ "$CUDA_TAG" = "cu130" ]; then
  echo "==> Installing PyTorch with CUDA 13..."
  uv pip install "torch==2.10.0+cu130" "torchvision" "torchaudio" \
    --index-url https://download.pytorch.org/whl/cu130
fi

echo "==> Installing vLLM-Omni from matching GitHub tag..."
uv pip install --reinstall --no-deps \
  "git+https://github.com/vllm-project/vllm-omni.git@${VLLM_OMNI_GIT_REF}"

echo "==> Installing useful/runtime clients..."
uv pip install -U \
  openai \
  httpx \
  soundfile \
  huggingface_hub \
  hf_transfer \
  librosa \
  scipy \
  numpy \
  aenum \
  accelerate \
  "cache-dit" \
  diffusers \
  "fa3-fwd==0.0.2" \
  imageio[ffmpeg] \
  janus \
  omegaconf \
  onnxruntime \
  "openai-whisper>=20250625" \
  prettytable \
  pydub \
  resampy \
  sox \
  torchsde \
  "x-transformers>=2.12.2"

# Pin torch to 2.10.0 to avoid version conflicts with vLLM
if [ "$CUDA_TAG" = "cu130" ]; then
  echo "==> Pinning PyTorch to 2.10.0..."
  uv pip install "torch==2.10.0" "torchvision" "torchaudio" \
    --index-url https://download.pytorch.org/whl/cu130 --upgrade
fi

echo "==> Verifying imports..."
python - <<'PY'
import sys
import pkgutil

import vllm
print("OK: vLLM:", getattr(vllm, "__version__", "unknown"))
print("vLLM path:", vllm.__file__)
print("Python:", sys.executable)

try:
    import vllm_omni
    print("OK: vLLM-Omni:", getattr(vllm_omni, "__version__", "unknown"))
    print("vLLM-Omni path:", vllm_omni.__file__)
except Exception as e:
    print("ERROR: vLLM-Omni import failed:", repr(e))

    try:
        import vllm.inputs
        print("vllm.inputs path:", vllm.inputs.__file__)
        print("vllm.inputs modules:", [m.name for m in pkgutil.iter_modules(vllm.inputs.__path__)])
    except Exception as e2:
        print("Could not inspect vllm.inputs:", repr(e2))

    raise

print("OK: install verification complete")
PY

echo
echo "✅ Install OK"
echo
echo "Run:"
echo "  source ./run.sh 0.0.0.0 8091"
