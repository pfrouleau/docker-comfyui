ARG BASE_IMAGE=nvidia/cuda:12.6.3-devel-ubuntu22.04
FROM ${BASE_IMAGE} AS base

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN set -xe && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        cmake \
        curl \
        git \
        iproute2 \
        libbz2-dev \
        libegl1 \
        libgl1 \
        libgl1-mesa-dev \
        libgl1-mesa-glx \
        libglib2.0-0 \
        libglu1-mesa-dev \
        libglvnd-dev \
        libglx0 \
        libopencv-dev \
        libopengl0 \
        libx11-dev \
        libxcursor-dev \
        libxi-dev \
        libxinerama-dev \
        libxrandr-dev \
        mesa-common-dev \
        mesa-utils \
        nano \
        ninja-build \
        pkg-config \
        python-is-python3 \
        python3 \
        python3-dev \
        python3-opencv \
        python3-pip \
        python3-psutil \
        rsync \
        software-properties-common \
        unzip \
        wget \
        xauth \
        xvfb && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        libavcodec-dev \
        libavdevice-dev \
        libavfilter-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev \
        libswscale-dev \
        python3-av && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

# Install Python packages globally
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch with CUDA support before ComfyUI installation
RUN pip3 install --no-cache-dir \
    torch \
    torchvision \
    torchaudio

# Setup ComfyUI in /opt (read-only application directory)
ARG VERSION=v0.3.26
RUN set -xe && \
    git clone https://github.com/comfyanonymous/ComfyUI.git /opt/comfyui && \
    cd /opt/comfyui && \
    git fetch --all --tags && \
    git checkout ${VERSION} && \
    pip3 install --no-cache-dir -r requirements.txt && \
    pip3 install --no-cache-dir comfy-cli

# Setup ComfyUI Manager
ARG UI_MANAGER_VERSION=main
RUN set -xe && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git /opt/comfyui/custom_nodes/ComfyUI-Manager && \
    cd /opt/comfyui/custom_nodes/ComfyUI-Manager && \
    git fetch --all --tags && \
    git checkout ${UI_MANAGER_VERSION} && \
    pip3 install --no-cache-dir -r requirements.txt

# Create directories and copy entrypoint
ARG BUILD_DATE
COPY ./runtime-assets/usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Create data directories with proper permissions for any user
RUN set -xe && \
    mkdir -p /data/{models,output,input,user,custom_nodes} && \
    chmod -R 777 /data && \
    chmod -R 755 /opt/comfyui

# Labels / Metadata
LABEL \
    org.opencontainers.image.authors="James Brink <brink.james@gmail.com>" \
    org.opencontainers.image.description="ComfyUI Interface for Stable Diffusion" \
    org.opencontainers.image.revision="1" \
    org.opencontainers.image.source="https://github.com/jamesbrink/docker-comfyui" \
    org.opencontainers.image.title="comfyui" \
    org.opencontainers.image.vendor="jamesbrink" \
    org.opencontainers.image.version="${VERSION}" \
    org.opencontainers.image.created="${BUILD_DATE}"

# Environment variables
ARG MULTI_USER=false
ENV \
    DISPLAY=:99 \
    HOME="/data/user" \
    NVIDIA_DRIVER_CAPABILITIES=all \
    PATH="/usr/local/bin:/data/user/.local/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    VERSION="${VERSION}" \
    COMFYUI_PATH="/opt/comfyui" \
    MULTI_USER="${MULTI_USER}" \
    DATA_PATH="/data"

# Use a high UID that's less likely to conflict
# This works better with both Docker and Podman user namespace mapping
ARG USER_ID=10001
ARG GROUP_ID=10001

RUN set -xe && \
    groupadd -g ${GROUP_ID} comfyui && \
    useradd -u ${USER_ID} -g ${GROUP_ID} -d /data/user -s /bin/bash -m comfyui && \
    chown -R comfyui:comfyui /data

# Switch to non-root user
USER comfyui
WORKDIR /data/user

# Setup git for the user
RUN set -xe && \
    git config --global user.name "ComfyUI" && \
    git config --global user.email "comfyui@container.local" && \
    git config --global init.defaultBranch main && \
    git config --global core.editor "nano" && \
    git config --global --add safe.directory "*"

# Expose HTTP port
EXPOSE 8188

# Volumes for data persistence
VOLUME ["/data/models", "/data/output", "/data/input", "/data/user", "/data/custom_nodes"]

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command arguments
CMD ["--listen", "--port", "8188", "--preview-method", "auto"]
