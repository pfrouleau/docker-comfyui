# CLAUDE.md - Docker ComfyUI Repository Guidelines

## Build Commands
- `make` or `make base` - Build base Docker image
- `make sd-1.5` - Build with SD 1.5 model
- `make sd-turbo` - Build with SD Turbo model
- `make svd` - Build with SVD models
- `make all-models` - Build with all models

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