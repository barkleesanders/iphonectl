.PHONY: build test lint install clean

BIN_EXT := $(if $(filter windows,$(shell go env GOOS)),.exe,)

build:
	go build -o bin/iphonectl-pp-cli$(BIN_EXT) ./cmd/iphonectl-pp-cli

test:
	go test ./...

lint:
	golangci-lint run

install:
	go install ./cmd/iphonectl-pp-cli

clean:
	rm -rf bin/

build-mcp:
	go build -o bin/iphonectl-pp-mcp$(BIN_EXT) ./cmd/iphonectl-pp-mcp

install-mcp:
	go install ./cmd/iphonectl-pp-mcp

build-all: build build-mcp
