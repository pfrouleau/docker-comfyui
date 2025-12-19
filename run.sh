#!/bin/bash

# label=disable is required to avoid libc.so.6 error with Fedora
# --init helps to cleanly stop the container instead of waiting for the timeout

# Ensure necessary directories exist
mkdir -p ./user ./models ./output ./input ./custom_nodes

podman run -d --name comfyui \
    --init \
    --device nvidia.com/gpu=all \
    --security-opt label=disable \
    -v ./user:/opt/comfyui/user:Z \
    -v ./models:/opt/comfyui/models:Z \
    -v ./output:/opt/comfyui/output:Z \
    -v ./input:/opt/comfyui/input:Z \
    -p 8188:8188 \
    jamesbrink/comfyui
#    -v ./custom_nodes:/opt/comfyui/custom_nodes:Z \
if [ $? -eq 0 ]; then
    echo "ComfyUI is running and accessible at http://localhost:8188"
else
    echo "Failed to start ComfyUI container."
    podman logs comfyui
fi
