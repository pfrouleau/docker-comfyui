#!/usr/bin/make -f

SHELL                   := /usr/bin/env bash

# Load environment variables from .env file if it exists, otherwise from default.env
ifneq (,$(wildcard .env))
	include .env
	export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env)
else ifneq (,$(wildcard default.env))
    include default.env
    export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' default.env)
endif

# Function to require a variable
require = $(if $(strip $($(1))),,$(error Variable $(1) is required but not set. Please set it in .env or environment))

# Required variables using the function
REQUIRED_VARS := \
	REPO_NAMESPACE \
	REPO_USERNAME \
	REPO_NAME \
	CUDA_VERSION \
	OS_VERSION \
	COMFYUI_VERSION \
	CONTAINER_AUTHORS \
	MULTI_USER

# Print required variables
$(foreach v,$(strip $(REQUIRED_VARS)),$(info $(v)=$($(v))))

$(foreach v,$(strip $(REQUIRED_VARS)),$(call require,$(v)))

# Optional variables with defaults
REPO_API_URL            ?= https://hub.docker.com/v2
IMAGE_NAME              ?= comfyui
UI_MANAGER_VERSION      ?= main
COMFYUI_CACHE_RAM       ?= 16

#BASE_IMAGE              := nvidia/cuda:$(CUDA_VERSION)-devel-$(OS_VERSION)
BASE_IMAGE              := nvidia/cuda:$(CUDA_VERSION)-devel-$(OS_VERSION)
SED                     := $(shell [[ `command -v gsed` ]] && echo gsed || echo sed)
BUILD_DATE              := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

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
		--build-arg COMFYUI_CACHE_RAM=$(COMFYUI_CACHE_RAM) \
		--build-arg REPO_NAMESPACE=$(REPO_NAMESPACE) \
		--build-arg REPO_USERNAME=$(REPO_USERNAME) \
		--build-arg REPO_NAME=$(REPO_NAME) \
		--build-arg CONTAINER_AUTHORS=$(CONTAINER_AUTHORS) \
		--build-arg IMAGE_NAME=$(IMAGE_NAME) \
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

# Run container in single-user mode (default)
.PHONY: run
run:
	docker run --rm -p 8188:8188 \
		--gpus all \
		--shm-size=8g \
		--ipc=host \
		--ulimit memlock=-1 \
		--ulimit stack=67108864 \
		-e MULTI_USER=$(MULTI_USER) \
		-e COMFYUI_CACHE_RAM=$(COMFYUI_CACHE_RAM) \
		$(REPO_NAMESPACE)/$(IMAGE_NAME)
