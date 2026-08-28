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

# Set CUDA home path once (assumes CUDA is provided by the base image)
ENV CUDA_HOME=/usr/local/cuda

# Upgrade pip and setuptools
RUN python -m pip install --no-cache-dir --upgrade \
    pip setuptools wheel

# Pin the PyTorch stack explicitly to improve GPU compatibility and reduce drift
ARG TORCH_VERSION=2.10.0
ARG TORCHVISION_VERSION=0.25.0
ARG TORCHAUDIO_VERSION=2.10.0
ARG TORCH_CUDA_ARCH_LIST=8.9
ARG PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu130
ARG XFORMERS_VERSION=

# Expose Torch CUDA arch list as an environment variable for builds
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}

RUN set -xe && \
    if [ -n "${PYTORCH_INDEX_URL}" ]; then \
        python -m pip install --no-cache-dir --index-url "${PYTORCH_INDEX_URL}" \
            "torch==${TORCH_VERSION}" \
            "torchvision==${TORCHVISION_VERSION}" \
            "torchaudio==${TORCHAUDIO_VERSION}"; \
    else \
        python -m pip install --no-cache-dir \
            "torch==${TORCH_VERSION}" \
            "torchvision==${TORCHVISION_VERSION}" \
            "torchaudio==${TORCHAUDIO_VERSION}"; \
    fi

# Install dependencies for flash-attn and other packages
RUN pip install --no-cache-dir \
    packaging \
    psutil \
    ninja

# Install flash-attn only when a compatible wheel is available; otherwise skip it.
RUN set -xe && \
    if pip install --no-cache-dir --disable-pip-version-check --no-build-isolation flash-attn; then \
        echo "flash-attn installed successfully"; \
    else \
        echo "⚠️  Warning: flash-attn installation failed or is unsupported for this torch/CUDA combination; continuing without it"; \
    fi

# Install optional xformers support by building from source so it links
# against the installed PyTorch/CUDA in this image (avoids prebuilt wheel
# ABI mismatches across torch/cuda/python versions).
RUN set -xe && \
    pip uninstall -y xformers || true && \
    if [ -n "${XFORMERS_VERSION}" ]; then \
        XFORMERS_REF="@${XFORMERS_VERSION}"; \
    else \
        XFORMERS_REF=""; \
    fi && \
    python -m pip install --no-cache-dir --no-build-isolation --no-binary :all: \
        "git+https://github.com/facebookresearch/xformers${XFORMERS_REF}" || true

# Install additional dependencies for QwenVL flash attention support
RUN pip install --no-cache-dir \
    accelerate \
    einops \
    llama-cpp-python \
    "transformers>=4.50.3"

# Install additional dependencies for ComfyUI-manager
RUN pip install --no-cache-dir \
    deepdiff \
    matrix-nio

# Install additional dependencies for Crystools
RUN pip install --no-cache-dir \
    piexif \
    py-cpuinfo \
    pynvml

# Install SageAttention for memory-efficient attention (built with CUDA support)
ARG SAGEATTENTION_VERSION=v2.2.0
RUN SAGE_ATTN_DIR=/tmp/SageAttention && \
    git clone https://github.com/thu-ml/SageAttention.git $SAGE_ATTN_DIR && \
    cd $SAGE_ATTN_DIR && \
    git checkout ${SAGEATTENTION_VERSION} && \
    pip install --no-cache-dir --no-build-isolation . && \
    cd /tmp && \
    rm -rf $SAGE_ATTN_DIR

# Setup ComfyUI in /opt
ARG COMFYUI_VERSION
RUN test -n "$COMFYUI_VERSION" || \
    (echo "ERROR: COMFYUI_VERSION build argument is required. Usage: docker build --build-arg COMFYUI_VERSION=v0.3.34 ." && exit 1) && \
    set -xe && \
    WORKDIR=/opt/comfyui && \
    git clone --depth=1 --branch=${COMFYUI_VERSION} \
        https://github.com/comfyanonymous/ComfyUI.git $WORKDIR && \
    cd $WORKDIR && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r manager_requirements.txt && \
    pip install --no-cache-dir comfy-cli && \
    echo "N" | comfy tracking disable 2>/dev/null

ENV COMFYUI_PATH="/opt/comfyui"

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
ARG COMFYUI_CACHE_RAM=16
ENV \
    CUDA_DEVICE_ORDER=PCI_BUS_ID \
    DISPLAY=:99 \
    HOME="/data/user" \
    MKL_NUM_THREADS=8 \
    NVIDIA_DRIVER_CAPABILITIES=all \
    NVIDIA_VISIBLE_DEVICES=all \
    OMP_NUM_THREADS=8 \
    PATH="/usr/local/bin:/data/user/.local/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTORCH_CUDA_ALLOC_CONF="garbage_collection_threshold:0.6,max_split_size_mb:128" \
    COMFYUI_VERSION="${COMFYUI_VERSION}" \
    COMFYUI_PATH="/opt/comfyui" \
    COMFYUI_CACHE_RAM="${COMFYUI_CACHE_RAM}" \
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
CMD ["--enable-manager", "--listen", "--port", "8188", "--preview-method", "auto"]
