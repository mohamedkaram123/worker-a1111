#!/usr/bin/env bash

echo "🚀 Worker Initiated"
echo "🔧 Starting WebUI API"

# استخدام TCMalloc لتحسين الأداء
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PYTHONUNBUFFERED=true

# تأكد من وجود ملف التكوين لتحسين الوجوه
mkdir -p /stable-diffusion-webui/models/FaceRestoration
if [ ! -f /stable-diffusion-webui/config.json ]; then
  echo "Creating face restoration configuration..."
  echo '{
    "face_restoration_model": "CodeFormer",
    "code_former_weight": 0.8,
    "face_restoration_strength": 0.75
  }' > /stable-diffusion-webui/config.json
fi

# تشغيل WebUI A1111 API فقط بدون واجهة
python /stable-diffusion-webui/webui.py \
  --xformers \
  --no-half-vae \
  --skip-python-version-check \
  --skip-torch-cuda-test \
  --skip-install \
  --ckpt /stable-diffusion-webui/models/Stable-diffusion/sd_xl_base_1.0.safetensors \
  --opt-sdp-attention \
  --disable-safe-unpickle \
  --port 3000 \
  --api \
  --nowebui \
  --skip-version-check \
  --no-hashing \
  --no-download-sd-model \
  --enable-insecure-extension-access \
  --listen \
  --enable-console-prompts \
  --face-restoration-model=CodeFormer \
  --codeformer-weight=0.8 \
  --face-restoration-unload=false \
  --reinstall-xformers \
  --no-half-vae &

echo "🔧 Activating face restoration models..."
mkdir -p /stable-diffusion-webui/models/FaceRestoration

# بدء معالج RunPod (handler)
echo "⚙️ Starting RunPod Handler"

# Copy the handler.py to a known location
cp /stable-diffusion-webui/handler.py /handler.py 2>/dev/null || echo "Could not copy handler.py from stable-diffusion-webui"

# Run handler from the correct location
if [ -f "/handler.py" ]; then
  echo "Running handler.py from root"
  python -u /handler.py
elif [ -f "/stable-diffusion-webui/handler.py" ]; then
  echo "Running handler.py from stable-diffusion-webui"
  python -u /stable-diffusion-webui/handler.py
else
  echo "ERROR: handler.py not found. Checking locations:"
  echo "Current directory:"
  pwd
  ls -la
  echo "Stable-diffusion-webui directory:"
  ls -la /stable-diffusion-webui
fi