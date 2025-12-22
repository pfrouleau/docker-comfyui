#!/bin/bash
set -e

# Function to create working directory if it doesn't exist
create_working_directory() {
    local work_dir="${DATA_PATH}/work"
    if [ ! -d "$work_dir" ]; then
        echo "Creating working directory: $work_dir"
        mkdir -p "$work_dir"
        # Copy ComfyUI to working directory, creating symlinks to preserve disk space
        cp -rs "${COMFYUI_PATH}/." "$work_dir/"
        # Remove the symlinked custom_nodes and create real directory for mounted nodes
        rm -rf "$work_dir/custom_nodes"
        mkdir -p "$work_dir/custom_nodes"
        
        # Copy built-in custom nodes (like ComfyUI-Manager) to working directory
        if [ -d "${COMFYUI_PATH}/custom_nodes" ]; then
            cp -r "${COMFYUI_PATH}/custom_nodes/." "$work_dir/custom_nodes/"
        fi
    fi
    
    # Always ensure custom_nodes directory exists and link to data directory
    mkdir -p "${DATA_PATH}/custom_nodes"
    if [ -d "${DATA_PATH}/custom_nodes" ] && [ -d "$work_dir/custom_nodes" ]; then
        # Sync any custom nodes from data volume to working directory
        rsync -av "${DATA_PATH}/custom_nodes/" "$work_dir/custom_nodes/" 2>/dev/null || true
    fi
    
    # Create symlinks for data directories
    for dir in models output input; do
        if [ -L "$work_dir/$dir" ] || [ -d "$work_dir/$dir" ]; then
            rm -rf "$work_dir/$dir"
        fi
        ln -sf "${DATA_PATH}/$dir" "$work_dir/$dir"
    done
    
    echo "Working directory ready: $work_dir"
    export WORKING_DIR="$work_dir"
}

# Function to install requirements from custom nodes
install_custom_node_requirements() {
    local node_dir="$1"
    local node_name=$(basename "$node_dir")
    
    echo "Processing custom node: $node_name"
    
    # Install requirements.txt if it exists
    if [ -f "${node_dir}/requirements.txt" ]; then
        echo "Installing requirements for $node_name"
        pip3 install --user --no-cache-dir -r "${node_dir}/requirements.txt" || \
            echo "Warning: Some requirements failed to install for $node_name"
    fi
    
    # Install setup.py if it exists
    if [ -f "${node_dir}/setup.py" ]; then
        echo "Installing setup.py for $node_name"
        cd "$node_dir"
        pip3 install --user --no-cache-dir -e . || \
            echo "Warning: setup.py installation failed for $node_name"
        cd - > /dev/null
    fi
}

# Function to setup custom nodes
setup_custom_nodes() {
    local custom_nodes_dir="${WORKING_DIR}/custom_nodes"
    
    if [ ! -d "$custom_nodes_dir" ]; then
        echo "Custom nodes directory not found at $custom_nodes_dir"
        return 0
    fi

    # Process each custom node directory
    find "$custom_nodes_dir" -mindepth 1 -maxdepth 1 -type d | while read -r node_dir; do
        if [ -d "$node_dir" ]; then
            install_custom_node_requirements "$node_dir"
        fi
    done
}

# Function to display connection information
show_connection_info() {
    echo -e "\n################################################################################"
    echo "ComfyUI is starting..."
    echo "Server will be available at:"
    echo "  - http://localhost:8188 (if using port forwarding)"
    echo "  - http://$(hostname):8188 (container hostname)"
    
    # Try to get local IP
    if command -v ip >/dev/null 2>&1; then
        LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}' 2>/dev/null || echo "unknown")
        if [ "$LOCAL_IP" != "unknown" ] && [ -n "$LOCAL_IP" ]; then
            echo "  - http://$LOCAL_IP:8188 (local network)"
        fi
    fi
    echo "################################################################################"
    echo ""
}

# Function to setup ComfyUI CLI
setup_comfy_cli() {
    # Disable tracking
    echo "N" | comfy tracking disable 2>/dev/null || true
    
    # Install completion if possible
    comfy --install-completion 2>/dev/null || true
    
    # Install some useful custom nodes
    echo "Installing recommended custom nodes..."
    comfy node install --mode remote ComfyUI-Crystools ComfyUI-Custom-Scripts 2>/dev/null || \
        echo "Note: Some custom nodes could not be installed automatically"
}

# Main execution
echo "Starting ComfyUI entrypoint..."

# Start Xvfb for headless graphics
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset > /dev/null 2>&1 &
export DISPLAY=:99
export MODERNGL_WINDOW=headless
export NVIDIA_DRIVER_CAPABILITIES=all

# Wait for Xvfb to start
sleep 2

# Create working directory and setup environment
create_working_directory

# Setup git safe directories - handle potential permission issues gracefully
git config --global --add safe.directory "*" 2>/dev/null || true

# Display connection information
show_connection_info

# Change to working directory
cd "$WORKING_DIR"

# Setup ComfyUI CLI tools
setup_comfy_cli

# Setup custom nodes
echo "Setting up custom nodes..."
setup_custom_nodes

# Determine startup flags
flags="$@"
# Add multi-user flag if enabled
if [ "${MULTI_USER:-false}" = "true" ]; then
    flags="$flags --multi-user"
    echo "Multi-user mode enabled"
fi

echo "Starting ComfyUI with custom flags: $flags"
exec python3 main.py $flags
