#!/usr/bin/make -f

SHELL                   := /usr/bin/env bash
REPO_NAMESPACE          ?= jamesbrink
REPO_USERNAME           ?= jamesbrink
REPO_API_URL            ?= https://hub.docker.com/v2
IMAGE_NAME              ?= comfyui
CUDA_VERSION            ?= 12.6.3
BASE_IMAGE              ?= nvidia/cuda:$(CUDA_VERSION)-devel-ubuntu22.04
SED                     := $(shell [[ `command -v gsed` ]] && echo gsed || echo sed)
BUILD_DATE              := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
COMFYUI_VERSION         ?= v0.3.34
UI_MANAGER_VERSION      ?= main
MULTI_USER              ?= false

# Default target is to build container
.PHONY: default
default: build

# Build the docker image
.PHONY: build
build:
	docker build \
		--security-opt label=disable \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg COMFYUI_VERSION=$(COMFYUI_VERSION) \
		--build-arg MULTI_USER=$(MULTI_USER) \
		--tag $(REPO_NAMESPACE)/$(IMAGE_NAME):latest \
		--tag $(REPO_NAMESPACE)/$(IMAGE_NAME):$(COMFYUI_VERSION) \
		--file Dockerfile .;

# Alias for build
.PHONY: base
base: build

# Push the docker image
.PHONY: push
push: build
	docker push $(REPO_NAMESPACE)/$(IMAGE_NAME):latest; \
	docker push $(REPO_NAMESPACE)/$(IMAGE_NAME):$(COMFYUI_VERSION);

# List built images
.PHONY: list
list:
	docker images $(REPO_NAMESPACE)/$(IMAGE_NAME)

# Run any tests
.PHONY: test
test:
	docker run --rm --entrypoint="" -t $(REPO_NAMESPACE)/$(IMAGE_NAME) env | grep COMFYUI_VERSION | grep $(COMFYUI_VERSION)

# Remove existing images
.PHONY: clean
clean:
	docker rmi $$(docker images $(REPO_NAMESPACE)/$(IMAGE_NAME) --format="{{.Repository}}:{{.Tag}}") --force
