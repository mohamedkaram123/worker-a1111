# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 as download

ARG HF_TOKEN

RUN apk add --no-cache wget

# إنشاء مجلدات النماذج
RUN mkdir -p /models/Stable-diffusion \
             /models/IP-Adapter

# Deliberate (لا يحتاج توكن)
RUN wget -O /models/Stable-diffusion/Deliberate_v6.safetensors \
     https://huggingface.co/XpucT/Deliberate/resolve/main/Deliberate_v6.safetensors

# SDXL Base
RUN wget --header "Authorization: Bearer ${HF_TOKEN}" \
     -O /models/Stable-diffusion/sd_xl_base_1.0.safetensors \
     https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# IP-Adapter
RUN wget --header "Authorization: Bearer ${HF_TOKEN}" \
     -O /models/IP-Adapter/ip-adapter-plus_sdxl.safetensors \
     https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sdxl.safetensors && \
    wget --header "Authorization: Bearer ${HF_TOKEN}" \
     -O /models/IP-Adapter/ip-adapter-plus_sdxl.yaml \
     https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sdxl.yaml

# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim as build_final_image

ARG A1111_RELEASE=v1.9.3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${A1111_RELEASE} && \
    pip install xformers && \
    pip install -r requirements_versions.txt && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

# نسخ النماذج من المرحلة الأولى
COPY --from=download /models /stable-diffusion-webui/models

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY test_input.json .
ADD src .

RUN chmod +x /start.sh
CMD /start.sh
