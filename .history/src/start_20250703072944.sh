#!/usr/bin/env bash

echo "🚀 Worker Initiated"
echo "🔧 Starting WebUI API"

# استخدام TCMalloc لتحسين الأداء
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PYTHONUNBUFFERED=true

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
  --no-download-sd-model &

# بدء معالج RunPod (handler)
echo "⚙️ Starting RunPod Handler"
python -u /handler.py


echo "📦 Running model hash scanner..."
MODEL_DIR="/stable-diffusion-webui/extensions/sd-webui-controlnet/models"

cd "$MODEL_DIR" || { echo "❌ Model directory not found!"; exit 1; }

for model in *.safetensors; do
  if [[ -f "$model" ]]; then
    hash=$(sha256sum "$model" | cut -c1-8)
    echo "✅ Found: $model ➜ model line:"
    echo "\"model\": \"${model%.safetensors} [${hash}]\""
  fi
done