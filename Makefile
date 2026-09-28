# iphonectl — build both control paths + the controlphone entrypoint.
#
#   make            # build everything (Path B Go CLI+MCP, Path A native Swift)
#   make wda        # Path B: generated Go CLI + MCP server
#   make native     # Path A: native Swift tool
#   make install    # symlink bin/controlphone + built binaries into ~/.local/bin
#   make verify     # build, then read the connected device (no tunnel) as a smoke test
#   make clean

PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: all wda native install verify clean

all: wda native
	@echo "built: wda/iphonectl-pp-cli, native/.build/release/iphonectl-native, bin/controlphone"

wda:
	cd $(ROOT)/wda && go build -o iphonectl-pp-cli ./cmd/iphonectl-pp-cli
	cd $(ROOT)/wda && go build -o iphonectl-pp-mcp ./cmd/iphonectl-pp-mcp

native:
	cd $(ROOT)/native && swift build -c release

install: all
	mkdir -p $(BINDIR)
	ln -sf $(ROOT)/bin/controlphone       $(BINDIR)/controlphone
	ln -sf $(ROOT)/bin/iphonectl-setup    $(BINDIR)/iphonectl-setup
	ln -sf $(ROOT)/wda/iphonectl-pp-cli   $(BINDIR)/iphonectl-pp-cli
	ln -sf $(ROOT)/native/.build/release/iphonectl-native $(BINDIR)/iphonectl-native
	@echo "linked into $(BINDIR) — ensure it is on your PATH"

verify: all
	@echo "== controlphone list ==" && $(ROOT)/bin/controlphone list || true
	@echo "== controlphone info ==" && $(ROOT)/bin/controlphone info || true

clean:
	cd $(ROOT)/wda && rm -f iphonectl-pp-cli iphonectl-pp-mcp
	cd $(ROOT)/native && rm -rf .build
