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

# Copy entrypoint
COPY ./runtime-assets/usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Create comfyui user early for proper ownership of installed files
ARG USER_ID=10001
ARG GROUP_ID=10001

RUN set -xe && \
    groupadd -g ${GROUP_ID} comfyui && \
    useradd -u ${USER_ID} -g ${GROUP_ID} -d /data/user -s /bin/bash -m comfyui && \
    mkdir -p /data/models /data/output /data/input /data/user /data/custom_nodes /opt/comfyui /opt/venv && \
    chown -R comfyui:comfyui /data /opt/comfyui /opt/venv

# Switch to comfyui user for all installations
USER comfyui

# Create Python virtual environment as comfyui user
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
    pip3 install --no-cache-dir comfy-cli && \
    echo "N" | comfy tracking disable 2>/dev/null

# Setup ComfyUI Manager
ARG UI_MANAGER_VERSION=main
RUN set -xe && \
    WORKDIR=/opt/comfyui/custom_nodes/ComfyUI-Manager && \
    git clone --depth=1 --branch=${UI_MANAGER_VERSION} \
        https://github.com/ltdrdata/ComfyUI-Manager.git $WORKDIR && \
    cd $WORKDIR && \
    pip install --no-cache-dir -r requirements.txt

# COPY ./custom_nodes.lst /opt/comfyui/
#
# RUN set -xe && \
#     cd /opt/comfyui && \
#     echo "N" | comfy tracking disable 2>/dev/null && \
#     grep -v '^\s*#' /opt/comfyui/custom_nodes.lst | grep -v '^\s*$' | \
#     while read N ; do \
#         echo "Adding custom node from: $N" ; \
#         comfy node install --mode remote "$N" ; \
#     done && \
#     rm /opt/comfyui/custom_nodes.lst

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

# Switch to non-root user for final setup and execution
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
