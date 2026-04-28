FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV UV_SYSTEM_PYTHON=1
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV TOKENIZERS_PARALLELISM=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    build-essential \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app

ARG VLLM_VERSION=0.19.0
ARG VLLM_OMNI_GIT_REF=v0.19.0rc1

RUN uv venv --python 3.12 /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

RUN uv pip install -U pip setuptools wheel packaging ninja

RUN uv pip uninstall -y vllm vllm-omni || true

RUN uv pip install --reinstall "vllm==${VLLM_VERSION}" --torch-backend=auto

RUN uv pip install --reinstall --no-deps \
    "git+https://github.com/vllm-project/vllm-omni.git@${VLLM_OMNI_GIT_REF}"

RUN uv pip install -U \
    openai \
    httpx \
    soundfile \
    huggingface_hub \
    hf_transfer \
    librosa \
    scipy \
    numpy

RUN python - <<'PY'
import vllm
print("vLLM:", getattr(vllm, "__version__", "unknown"))

import vllm_omni
print("OK: vLLM-Omni:", getattr(vllm_omni, "__version__", "unknown"))
print("vLLM-Omni path:", vllm_omni.__file__)
PY

COPY run.sh /app/run.sh
COPY .env.example /app/.env.example

RUN chmod +x /app/run.sh

EXPOSE 8091

CMD ["/bin/bash", "-lc", "source /app/run.sh 0.0.0.0 8091"]
