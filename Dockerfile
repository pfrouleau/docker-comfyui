ARG BASE_IMAGE
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
        python3-psutil \
        python3-venv \
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

# Create Python virtual environment
RUN python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}"

# Upgrade pip and setuptools
RUN python -m pip install --no-cache-dir --upgrade \
    pip setuptools wheel

# Install PyTorch with CUDA support before ComfyUI installation
RUN pip install --no-cache-dir \
    torch \
    torchvision \
    torchaudio

# Setup ComfyUI in /opt
ARG COMFYUI_VERSION
RUN test -n "$COMFYUI_VERSION" || \
    (echo "ERROR: COMFYUI_VERSION build argument is required. Usage: docker build --build-arg COMFYUI_VERSION=v0.3.34 ." && exit 1) && \
    set -xe && \
    WORKDIR=/opt/comfyui && \
    git clone --depth=1 --branch=${COMFYUI_VERSION} \
        https://github.com/comfyanonymous/ComfyUI.git $WORKDIR && \
    cd $WORKDIR && \
    pip3 install --no-cache-dir -r requirements.txt && \
    pip3 install --no-cache-dir comfy-cli

# Setup ComfyUI Manager
ARG UI_MANAGER_VERSION=main
RUN set -xe && \
    WORKDIR=/opt/comfyui/custom_nodes/ComfyUI-Manager && \
    git clone --depth=1 --branch=${UI_MANAGER_VERSION} \
        https://github.com/ltdrdata/ComfyUI-Manager.git $WORKDIR && \
    cd $WORKDIR && \
    pip install --no-cache-dir -r requirements.txt

# Create directories and copy entrypoint
COPY ./runtime-assets/usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Create data directories with proper permissions for any user
RUN set -xe && \
    mkdir -p /data/{models,output,input,user,custom_nodes} && \
    chmod -R 777 /data && \
    chmod -R 755 /opt/comfyui

# Labels / Metadata
ARG BUILD_DATE
ARG IMAGE_NAME
ARG CONTAINER_AUTHORS
ARG REPO_NAME
ARG REPO_NAMESPACE
LABEL \
    org.opencontainers.image.authors="${CONTAINER_AUTHORS}" \
    org.opencontainers.image.description="ComfyUI Interface for Stable Diffusion" \
    org.opencontainers.image.revision="1" \
    org.opencontainers.image.source="https://github.com/${REPO_NAMESPACE}/${REPO_NAME}" \
    org.opencontainers.image.title="${IMAGE_NAME}" \
    org.opencontainers.image.vendor="${REPO_NAMESPACE}" \
    org.opencontainers.image.version="${COMFYUI_VERSION}" \
    org.opencontainers.image.created="${BUILD_DATE}"

# Environment variables
ARG MULTI_USER=false
ENV \
    DISPLAY=:99 \
    HOME="/data/user" \
    NVIDIA_DRIVER_CAPABILITIES=all \
    PATH="/usr/local/bin:/data/user/.local/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    COMFYUI_VERSION="${COMFYUI_VERSION}" \
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

# Allow comfyui user to manage the virtual environment
# Comment this out if you want improved security and want to manage packages dependencies yourself
RUN chown -R comfyui:comfyui /opt/venv && \
    chmod -R 755 /opt/venv

     # Switch to non-root user
USER comfyui
WORKDIR /data/user

# Setup git for the user
RUN set -xe && \
    git config --global user.name "ComfyUI" && \
    git config --global user.email "comfyui@container.local" && \
    git config --global init.defaultBranch main && \
    git config --global core.editor "nano" && \
    git config --global --add safe.directory "/opt/comfyui/custom_nodes*" && \
    git config --global --add safe.directory "$DATA_PATH/*"

# Expose HTTP port
EXPOSE 8188

# Volumes for data persistence
VOLUME ["/data/models", "/data/output", "/data/input", "/data/user"]

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command arguments
CMD ["--listen", "--port", "8188", "--preview-method", "auto"]
