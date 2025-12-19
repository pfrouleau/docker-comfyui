# Docker Image for ComfyUI (Stable Diffusion)

## About

A Docker image for running [ComfyUI][ComfyUI] with [ComfyUI Manager][ComfyUIManager] pre-installed. This image has been tested on **Linux with NVIDIA GPUs** and is fully compatible with both Docker and Podman.

**Current Version**: ComfyUI v0.5.1 (latest release)

### Key Features:
- ✅ **Latest ComfyUI**: v0.5.1 with newest dependencies and features
- ✅ **Permission-Fixed**: Works seamlessly with Docker and rootless Podman
- ✅ **Easy Updates**: Clean separation of application and user data
- ✅ **Data Persistence**: Workflows, models, and settings preserved across updates
- ✅ **Pre-installed Manager**: ComfyUI Manager for easy custom node management 

The following volume mounts are recommended for data persistence:
- `/data/user`: Contains your workflows and personal workspace settings. Always mount this to preserve your workflows when updating or recreating the container
- `/data/models`: Model files (checkpoints, VAE, Loras, etc.)
- `/data/output`: Generated images and other outputs
- `/data/input`: Input images and other data

The `/data/user` volume is particularly important as it stores your workflow files (`.json`), ensuring you don't lose your work when updating ComfyUI or rebuilding the container. Other volumes like `models`, `input`, and `output` can be shared between different AI tools for a more integrated setup.

## Updates and Upgrades

This container implements a clean separation between the ComfyUI application (in `/opt/comfyui`) and user data (in `/data`). To update ComfyUI:

1. Pull or build a newer version of the container
2. Stop the current container: `docker stop comfyui`
3. Start with the new image: `docker run ...` (same command as before)

Your user data, models, and custom nodes will be preserved across updates.

## Architecture & Performance

This container implements an optimized architecture designed for production use:

- **Application Layer**: ComfyUI installed in `/opt/comfyui` (read-only, versioned)
- **Data Layer**: User data in `/data` (persistent, user-controlled volumes)
- **Working Layer**: Symlinked copy in `/data/work` (efficient, space-saving)
- **Permission Model**: High UID (10001) for Docker/Podman compatibility
- **Update Model**: Rebuild container for app updates, volumes preserve data

## Usage

Build and run the container:

```shell
make build
docker run -d --gpus all -p 8188:8188 \
    -v ./user:/data/user \
    -v ./models:/data/models \
    -v ./output:/data/output \
    -v ./input:/data/input \
    --name comfyui jamesbrink/comfyui
```

Optionally run container on host network:  

```shell
docker run -d --gpus all --network=host \
    -v ./user:/data/user \
    -v ./models:/data/models \
    -v ./output:/data/output \
    -v ./input:/data/input \
    --name comfyui jamesbrink/comfyui
```

### Using with Podman

This image is fully compatible with Podman and rootless containers:

```shell
podman run -d --device nvidia.com/gpu=all -p 8188:8188 \
    --init \
    -v ./user:/data/user:Z \
    -v ./models:/data/models:Z \
    -v ./output:/data/output:Z \
    -v ./input:/data/input:Z \
    --name comfyui jamesbrink/comfyui
```

## Simplified usage

Copy `default.env` into `.env` and edit is values to your usage. You can update the versions
if you want to use newer ones, but you may have to fix the build sequence if there are news
dependencies. The REPO_ variables can be set different values if you want to have a distinct
name for the generated container image.

Build the container image as usual:

```shell
make build
```

Then use a directory to store all your volumes and copy these files into it:
- `run.sh`

That script starts the container if one exist, otherwise it create a new container.
Edit the file if you have modified the image name. 

```shell
./run.sh
```

### Shared Model Setup

If you want to share models between ComfyUI and other tools like Fooocus, you can create a centralized directory structure:

```shell
mkdir -p ~/AI/ComfyUI/user           # Workflows and workspace settings
mkdir -p ~/AI/Models/StableDiffusion # Shared models
mkdir -p ~/AI/Output                 # Generated images
mkdir -p ~/AI/Input                  # Input data
```

Then run the container with these mapped volumes:

```shell
docker run -d --gpus all --network=host \
    -v ~/AI/ComfyUI/user:/data/user \
    -v ~/AI/Models/StableDiffusion/:/data/models \
    -v ~/AI/Output:/data/output \
    -v ~/AI/Input:/data/input \
    --name comfyui jamesbrink/comfyui
```

## Kubernetes Deployment

The project includes Kubernetes manifests in the `k8s` directory for deploying ComfyUI in a Kubernetes cluster. The deployment requires a Kubernetes cluster with NVIDIA GPU support configured.

### Prerequisites

- Kubernetes cluster with NVIDIA GPU support (nvidia-device-plugin installed)
- kubectl configured to access your cluster
- Default StorageClass configured in your cluster

### Deployment Steps

1. Apply the PersistentVolumeClaims:
```shell
kubectl apply -f k8s/pvc.yaml
```

2. Deploy ComfyUI:
```shell
kubectl apply -f k8s/deployment.yaml
```

3. Create the service:
```shell
kubectl apply -f k8s/service.yaml
```

4. Access ComfyUI:

   The service is configured to support both ClusterIP and NodePort access modes. Choose the most appropriate method for your environment:

   a. **Port Forwarding (Testing)**:
      ```shell
      kubectl port-forward svc/comfyui 8188:8188
      ```

   b. **NodePort Access**:
      ```shell
      # Get the NodePort
      kubectl get svc comfyui -o jsonpath='{.spec.ports[0].nodePort}'
      # Access via any node's IP using the NodePort
      # http://<node-ip>:<node-port>
      ```

   c. **Ingress (Recommended for Production)**:
      ```shell
      # Install NGINX Ingress Controller if not already installed
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update
      helm install ingress-nginx ingress-nginx/ingress-nginx

      # Apply the ingress configuration
      kubectl apply -f k8s/ingress.yaml
      ```

      The included ingress configuration provides:
      - HTTP and HTTPS support (TLS configuration included but commented)
      - WebSocket support for real-time updates
      - Reasonable timeout values for long-running operations
      - Easy customization for domains and TLS

      To enable TLS:
      1. Uncomment the TLS section in `k8s/ingress.yaml`
      2. Replace `comfyui.example.com` with your domain
      3. Provide your TLS certificate in a secret named `comfyui-tls`

### Storage Configuration

The deployment uses five PersistentVolumeClaims:
- `comfyui-user-pvc`: 1GB for workflows and workspace settings
- `comfyui-models-pvc`: 200GB for model files
- `comfyui-custom-nodes-pvc`: 5GB for custom nodes and extensions
- `comfyui-output-pvc`: 10GB for generated images
- `comfyui-input-pvc`: 10GB for input data

Adjust the storage sizes in `k8s/pvc.yaml` according to your needs.

[ComfyUI]: https://github.com/comfyanonymous/ComfyUI
[ComfyUIManager]: https://github.com/ltdrdata/ComfyUI-Manager