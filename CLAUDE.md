# CLAUDE.md - Docker ComfyUI Repository Guidelines

## Build Commands
- `make build` or `make` or `make base` - Build Docker image
- `make push` - Build and push Docker image to Docker Hub

## Test Commands
- `make test` - Verify Docker image via VERSION env variable
- `make list` - List all built Docker images
- `make clean` - Remove all built Docker images

## Docker Run Commands
```bash
docker run -d --gpus all -p 8188:8188 \
    -v ./user:/comfyui/user \
    -v ./models:/comfyui/models \
    -v ./output:/comfyui/output \
    -v ./input:/comfyui/input \
    --name comfyui jamesbrink/comfyui
```

## Code Style Guidelines
- **Shell Scripts**: Use bash with `set -e` or `set -xe`, 4-space indentation
- **Docker**: Multi-stage builds, cleanup caches, drop to non-root user
- **Makefile**: Use `.PHONY`, 4-space indentation, variables at top
- **Git Commits**: Use conventional prefixes (feat:, fix:, docs:, chore:)
- **Python**: Python 3, requirements via pip, editable installs for dev