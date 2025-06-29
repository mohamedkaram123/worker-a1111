# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 AS download

RUN apk add --no-cache wget

# إنشاء مجلدات النماذج
RUN mkdir -p /models/Stable-diffusion \
             /models/IP-Adapter \
             /models/ControlNet

# Deliberate (لا يحتاج توكن)
RUN wget -O /models/Stable-diffusion/Deliberate_v6.safetensors \
    https://huggingface.co/XpucT/Deliberate/resolve/main/Deliberate_v6.safetensors

# SDXL Base
RUN wget -O /models/Stable-diffusion/sd_xl_base_1.0.safetensors \
    https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# IP-Adapter
RUN wget -O /models/IP-Adapter/ip-adapter-plus_sdxl.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors

# ControlNet (مثال على واحد فقط: canny)
RUN wget -O /models/ControlNet/control_v11p_sd15_canny.pth \
    https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth

# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim AS build_final_image

ARG A1111_RELEASE=v1.9.3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# النظام والتبعيات
RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

# تحميل A1111 + ControlNet + Additional Networks
RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${A1111_RELEASE} && \
    git clone https://github.com/Mikubill/sd-webui-controlnet.git extensions/sd-webui-controlnet && \
    git clone https://github.com/bmaltais/sd-webui-additional-networks.git extensions/sd-webui-additional-networks && \
    pip install xformers && \
    pip install -r requirements_versions.txt && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

# نسخ النماذج من المرحلة الأولى
COPY --from=download /models /stable-diffusion-webui/models

# نسخ موديلات ControlNet إلى الامتداد
RUN mkdir -p /stable-diffusion-webui/extensions/sd-webui-controlnet/models && \
    cp /stable-diffusion-webui/models/ControlNet/*.pth /stable-diffusion-webui/extensions/sd-webui-controlnet/models/

# باقات إضافية
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY test_input.json .
ADD src .

RUN chmod +x /start.sh
CMD /start.sh
