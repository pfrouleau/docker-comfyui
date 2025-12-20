#!/bin/bash

# label=disable is required to avoid libc.so.6 error with Fedora
# --init helps to cleanly stop the container instead of waiting for the timeout

# Ensure necessary directories exist
mkdir -p ./user ./models ./output ./input ./custom_nodes

IMAGE_NAMESPACE=jamesbrink
CONTAINER_NAME=comfyui

if [[ $1 == "renew" ]]; then
    echo "Removing existing ComfyUI container (if any)..."
    podman rm -f $CONTAINER_NAME
fi

if podman container exists comfyui
then
    echo "Starting existing ComfyUI container..."
    podman start $CONTAINER_NAME
else
    echo "Creating new ComfyUI container..."
    podman run -d --name $CONTAINER_NAME \
        --init \
        --device nvidia.com/gpu=all \
        --security-opt label=disable \
        -v ./user:/opt/comfyui/user:Z \
        -v ./models:/opt/comfyui/models:Z \
        -v ./output:/opt/comfyui/output:Z \
        -v ./input:/opt/comfyui/input:Z \
        -p 8188:8188 \
        $IMAGE_NAMESPACE/comfyui
    #    -v ./custom_nodes:/opt/comfyui/custom_nodes:Z \
    if [ $? -eq 0 ]; then
        echo "ComfyUI is running and accessible at http://localhost:8188"
        podman logs -f $CONTAINER_NAME
    else
        echo "Failed to start ComfyUI container."
        podman logs $CONTAINER_NAME
    fi
fi
