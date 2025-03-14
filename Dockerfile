ARG BASE_IMAGE=nvidia/cuda:12.6.3-devel-ubuntu22.04
FROM ${BASE_IMAGE} AS base

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install deps
RUN set -xe; \
    apt update && apt install -y \
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
        ninja-build \
        pkg-config \
        pkg-config \
        python-is-python3 \
        python3 \
        python3-dev \
        python3-opencv \
        python3-pip \
        python3-pip \
        python3-psutil \
        rsync \
        software-properties-common \
        sudo \
        unzip \
        vim \
        wget \
        xauth \
        xvfb; \
    add-apt-repository universe; \
    apt-get update && apt-get install -y \
        ffmpeg \
        libavcodec-dev \
        libavdevice-dev \
        libavfilter-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev \
        libswscale-dev \
        python3-av; \
    apt clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /var/cache/apt; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y;

ENV PATH="/root/.cargo/bin:${PATH}"

# Create our group & user.
RUN set -xe; \
    useradd -u 1000 -g 100 -G sudo -r -d /comfyui -s /bin/sh comfyui; \
    echo "comfyui ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    mkdir -p /comfyui; \
    mkdir -p /app;

# Setup ComfyUI
ARG VERSION=v0.3.26
RUN set -xe; \
    git clone https://github.com/comfyanonymous/ComfyUI.git /app; \
    cd /app; \
    git fetch --all --tags; \
    git checkout ${VERSION}; \
    pip install --no-cache-dir -r requirements.txt; \
    pip install --no-cache-dir comfy-cli;

# Setup ComfyUI Manager
ARG UI_MANAGER_VERSION=main
RUN set -xe; \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git /app/custom_nodes/ComfyUI-Manager; \
    cd /app/custom_nodes/ComfyUI-Manager; \
    git fetch --all --tags; \
    git checkout ${UI_MANAGER_VERSION}; \
    pip install --no-cache-dir -r requirements.txt;

ARG BUILD_DATE
# Copy our entrypoint into the container.
COPY ./runtime-assets /

# Ensure entrypoint is executable
RUN set -xe; \
    chmod 0755 /usr/local/bin/entrypoint.sh; \
    chown -R comfyui:users /app; \
    chown -R comfyui:users /comfyui;

# Labels / Metadata.
LABEL \
    org.opencontainers.image.authors="James Brink <brink.james@gmail.com>" \
    org.opencontainers.image.description="ComfyUI Interface for Stable Diffusion" \
    org.opencontainers.image.revision="1" \
    org.opencontainers.image.source="https://github.com/jamesbrink/comfyui" \
    org.opencontainers.image.title="comfyui" \
    org.opencontainers.image.vendor="jamesbrink" \
    org.opencontainers.image.version="${VERSION}" \
    org.opencontainers.image.created="${BUILD_DATE}"

# Setup our environment variables.
ENV \
    DISPLAY=:99 \
    HOME="/comfyui" \
    NVIDIA_DRIVER_CAPABILITIES=all \
    PATH="/usr/local/bin:/comfyui/.local/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    VERSION="${VERSION}"

# Drop down to our unprivileged user.
USER comfyui
WORKDIR /comfyui

# Setup git
RUN set -xe; \
    git config --global user.name "ComfyUI"; \
    git config --global user.email "ComfyUI@urandom.io"; \
    git config --global init.defaultBranch main; \
    git config --global core.editor "vim"; \
    git config --global --add safe.directory /comfyui; \
    git config --global --add safe.directory /comfyui/custom_nodes/ComfyUI-Manager;

# Expose our http port.
EXPOSE 8188

# Volumes
VOLUME [ "/comfyui", "/comfyui/models", "/comfyui/output", "/comfyui/input", "/comfyui/user" ]

# Set the entrypoint.
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

# Set the default command
CMD [ "--listen", "--port","8188", "--preview-method", "auto", "--multi-user" ]
