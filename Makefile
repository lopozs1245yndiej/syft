# Makefile for syft - a fork of anchore/syft

# Variables
BINARY := syft
GO := go
GOFLAGS ?= -trimpath
GOBUILD := $(GO) build $(GOFLAGS)
GOTEST := $(GO) test
GOVET := $(GO) vet
GOFMT := gofmt
GOLINT := golangci-lint

# Version information
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "v0.0.0-dev")
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build flags
LD_FLAGS := -ldflags "-X main.version=$(VERSION) -X main.gitCommit=$(GIT_COMMIT) -X main.buildDate=$(BUILD_DATE) -w -s"

# Directories
CMD_DIR := ./cmd/syft
DIST_DIR := ./dist
SNAPSHOT_DIR := ./snapshot

# Tool versions (managed by binny)
TOOL_DIR := ./.tool

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: all
all: clean build test ## Run clean, build, and test

.PHONY: build
build: ## Build the syft binary
	$(GOBUILD) $(LD_FLAGS) -o $(BINARY) $(CMD_DIR)

.PHONY: snapshot
snapshot: ## Build a snapshot release using goreleaser
	goreleaser release --snapshot --clean --skip=publish

.PHONY: test
test: ## Run unit tests
	$(GOTEST) -race -coverprofile=coverage.out ./...

.PHONY: test-integration
test-integration: ## Run integration tests
	$(GOTEST) -tags integration -race ./...

.PHONY: coverage
coverage: test ## Generate and display test coverage report
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated at coverage.html"

.PHONY: lint
lint: ## Run linters
	$(GOLINT) run ./...

.PHONY: fmt
fmt: ## Format Go source files
	$(GOFMT) -w -s .

.PHONY: fmt-check
fmt-check: ## Check Go source file formatting
	@if [ -n "$(shell $(GOFMT) -l .)" ]; then \
		echo "The following files are not formatted:"; \
		$(GOFMT) -l .; \
		exit 1; \
	fi

.PHONY: vet
vet: ## Run go vet
	$(GOVET) ./...

.PHONY: tidy
tidy: ## Tidy go modules
	$(GO) mod tidy

.PHONY: clean
clean: ## Remove build artifacts
	rm -f $(BINARY)
	rm -f coverage.out coverage.html
	rm -rf $(DIST_DIR) $(SNAPSHOT_DIR)

.PHONY: install
install: build ## Install the syft binary to GOPATH/bin
	$(GO) install $(LD_FLAGS) $(CMD_DIR)

.PHONY: bootstrap
bootstrap: ## Install project tooling dependencies
	$(GO) install github.com/anchore/binny@latest
	binny install

# Note: 'check' intentionally excludes integration tests for faster local feedback.
# Run 'make test-integration' separately when needed.
.PHONY: check
check: fmt-check vet lint test ## Run all checks (format, vet, lint, test)

.PHONY: version
version: ## Print version information
	@echo "Version:    $(VERSION)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"
