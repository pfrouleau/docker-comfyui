#!/usr/bin/make -f

SHELL                   := /usr/bin/env bash

# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export $(shell sed 's/=.*//' .env)
endif

# Function to require a variable
require = $(if $(strip $($(1))),,$(error Variable $(1) is required but not set. Please set it in .env or environment))

# Required variables using the function
REQUIRED_VARS := \
  REPO_NAMESPACE \
  REPO_USERNAME \
  REPO_NAME \
  COMFY_VERSION \
  CUDA_VERSION \
  OS_VERSION \
  CONTAINER_AUTHORS

$(foreach v,$(REQUIRED_VARS),$(call require,$(v)))

# Optional variables with defaults
REPO_API_URL            ?= https://hub.docker.com/v2
IMAGE_NAME              ?= comfyui
UI_MANAGER_VERSION      ?= main
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
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg COMFY_VERSION=$(COMFY_VERSION) \
		--build-arg REPO_NAMESPACE=$(REPO_NAMESPACE) \
		--build-arg REPO_USERNAME=$(REPO_USERNAME) \
		--build-arg REPO_NAME=$(REPO_NAME) \
		--build-arg CONTAINER_AUTHORS=$(CONTAINER_AUTHORS) \
		--tag $(REPO_NAMESPACE)/$(IMAGE_NAME)-multistaged:latest \
		--tag $(REPO_NAMESPACE)/$(IMAGE_NAME)-multistaged:$(COMFY_VERSION) \
		--security-opt label=disable \
		--file Dockerfile.multistage .;

# Alias for build
.PHONY: base
base: build

# Push the docker image
.PHONY: push
push: build
	docker push $(REPO_NAMESPACE)/$(IMAGE_NAME):latest; \
	docker push $(REPO_NAMESPACE)/$(IMAGE_NAME):$(COMFY_VERSION);

# List built images
.PHONY: list
list:
	docker images $(REPO_NAMESPACE)/$(IMAGE_NAME)

# Run any tests
.PHONY: test
test:
	docker run --rm --entrypoint="" -t $(REPO_NAMESPACE)/$(IMAGE_NAME) env | grep COMFY_VERSION | grep $(COMFY_VERSION)

# Remove existing images
.PHONY: clean
clean:
	docker rmi $$(docker images $(REPO_NAMESPACE)/$(IMAGE_NAME) --format="{{.Repository}}:{{.Tag}}") --force
