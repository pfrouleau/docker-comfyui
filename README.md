# Docker Image for ComfyUI (Stable Diffusion)

## About

A Docker image for running [ComfyUI][ComfyUI] with [ComfyUI Manager][ComfyUIManager] pre-installed. This image has been tested on **Linux with NVIDIA GPUs**. 

The following volume mounts are recommended for data persistence:
- `/comfyui/user`: Contains your workflows and personal workspace settings. Always mount this to preserve your workflows when updating or recreating the container
- `/comfyui/models`: Model files (checkpoints, VAE, Loras, etc.)
- `/comfyui/custom_nodes`: Custom nodes and extensions
- `/comfyui/output`: Generated images and other outputs
- `/comfyui/input`: Input images and other data

The `/comfyui/user` volume is particularly important as it stores your workflow files (`.json`), ensuring you don't lose your work when updating ComfyUI or rebuilding the container. Other volumes like `models`, `input`, and `output` can be shared between different AI tools for a more integrated setup.

## Usage

Build and run the container:

```shell
make build
docker run -d --gpus all -p 8188:8188 \
    -v ./user:/comfyui/user \
    -v ./models:/comfyui/models \
    -v ./output:/comfyui/output \
    -v ./input:/comfyui/input \
    --name comfyui jamesbrink/comfyui
```

Optionally run container on host network:  

```shell
docker run -d --gpus all --network=host \
    -v ./user:/comfyui/user \
    -v ./models:/comfyui/models \
    -v ./output:/comfyui/output \
    -v ./input:/comfyui/input \
    --name comfyui jamesbrink/comfyui
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
    -v ~/AI/ComfyUI/user:/comfyui/user \
    -v ~/AI/Models/StableDiffusion/:/comfyui/models \
    -v ~/AI/Output:/comfyui/output \
    -v ~/AI/Input:/comfyui/input \
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

The deployment uses four PersistentVolumeClaims:
- `comfyui-user-pvc`: 1GB for workflows and workspace settings
- `comfyui-models-pvc`: 50GB for model files
- `comfyui-output-pvc`: 10GB for generated images
- `comfyui-input-pvc`: 10GB for input data

Adjust the storage sizes in `k8s/pvc.yaml` according to your needs.

[ComfyUI]: https://github.com/comfyanonymous/ComfyUI
[ComfyUIManager]: https://github.com/ltdrdata/ComfyUI-Manager