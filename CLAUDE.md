# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- **Shell Scripts**: Use bash with `#!/bin/bash`, functions for reusability, error handling with `|| echo` for warnings
- **Docker**: Multi-stage builds, cleanup apt caches, drop to non-root user (comfyui:users), use `set -xe` for debugging
- **Makefile**: Use `.PHONY` targets, 4-space indentation, variables at top, semicolons after commands
- **Git Commits**: Use conventional prefixes (feat:, fix:, docs:, chore:) with emojis
- **Python**: Use pip with `--no-cache-dir`, editable installs with `-e .`, handle requirement.txt files
- **Volume Mounts**: Always preserve `/comfyui/user` for workflows, separate data persistence patterns