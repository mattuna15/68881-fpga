# Merlin 2 GCC Cross-Compiler Toolchain (Cygwin)
#
# Builds m68k-elf-gcc from the upstream merlin-68k-toolchain submodule,
# adapted for Cygwin on Windows, with a Merlin 2 BSP.
#
# Build order: binutils -> gcc (stage 1) -> newlib + merlin2 BSP -> gcc (libgcc)
#
# Usage:
#   make all          -- full build (30-60 min)
#   make binutils     -- just binutils
#   make gcc-stage1   -- just gcc (no libgcc yet)
#   make newlib       -- newlib + merlin2 BSP
#   make gcc-libgcc   -- rebuild libgcc against newlib
#   make examples     -- build example programs
#   make clean        -- remove build artifacts (not installed files)

SHELL := /bin/bash

# Installation directory (must be in PATH for gcc-stage1 to find binutils)
INSTALL_DIR ?= $(HOME)/.local
BIN_DIR     ?= $(INSTALL_DIR)/bin
export PATH := $(BIN_DIR):$(PATH)

# Parallel jobs
JOBS ?= $(shell nproc)

# Source versions
BINUTILS_VER ?= 2.44
GCC_VER      ?= 14.2.0
NEWLIB_VER   ?= 4.5.0.20241231

# Build directories
TMP       ?= /tmp
BUILD_DIR ?= $(HOME)/.m68k-build
BINUTILS_SRC := $(BUILD_DIR)/binutils-$(BINUTILS_VER)
GCC_SRC      := $(BUILD_DIR)/gcc-$(GCC_VER)
GCC_BUILD    := $(BUILD_DIR)/gcc-build
NEWLIB_SRC   := $(BUILD_DIR)/newlib-$(NEWLIB_VER)
NEWLIB_BUILD := $(BUILD_DIR)/newlib-build

# Upstream submodule (not modified)
UPSTREAM := $(CURDIR)/merlin-68k-toolchain

# Merlin 2 BSP sources
BSP_DIR := $(CURDIR)/merlin2-bsp

# Use HTTPS mirrors (FTP often blocked)
BINUTILS_URL := https://sourceware.org/pub/binutils/releases/binutils-$(BINUTILS_VER).tar.gz
GCC_URL      := https://gcc.gnu.org/pub/gcc/releases/gcc-$(GCC_VER)/gcc-$(GCC_VER).tar.gz
NEWLIB_URL   := https://sourceware.org/pub/newlib/newlib-$(NEWLIB_VER).tar.gz

# Stamp files to track completed stages
STAMP_DIR    := $(BUILD_DIR)/stamps
STAMP_BINUTILS := $(STAMP_DIR)/binutils.done
STAMP_GCC1     := $(STAMP_DIR)/gcc-stage1.done
STAMP_NEWLIB   := $(STAMP_DIR)/newlib.done
STAMP_LIBGCC   := $(STAMP_DIR)/libgcc.done

# ============================================================================
# Top-level targets
# ============================================================================

.PHONY: all binutils gcc-stage1 newlib gcc-libgcc examples clean prereqs

all: binutils gcc-stage1 newlib gcc-libgcc
	@echo ""
	@echo "=== Toolchain build complete ==="
	@echo "  m68k-elf-gcc installed to: $(BIN_DIR)"
	@echo "  Run: export PATH=$(BIN_DIR):\$$PATH"
	@echo ""

# ============================================================================
# Prerequisites check
# ============================================================================

prereqs:
	@echo "Checking prerequisites..."
	@which gcc      >/dev/null 2>&1 || (echo "ERROR: gcc not found"; exit 1)
	@which make     >/dev/null 2>&1 || (echo "ERROR: make not found"; exit 1)
	@which bison    >/dev/null 2>&1 || (echo "ERROR: bison not found - install with: setup-x86_64.exe -q -P bison"; exit 1)
	@which flex     >/dev/null 2>&1 || (echo "ERROR: flex not found - install with: setup-x86_64.exe -q -P flex"; exit 1)
	@which makeinfo >/dev/null 2>&1 || (echo "ERROR: makeinfo not found - install with: setup-x86_64.exe -q -P texinfo"; exit 1)
	@which wget     >/dev/null 2>&1 || (echo "ERROR: wget not found - install with: setup-x86_64.exe -q -P wget"; exit 1)
	@echo "All prerequisites found."

# ============================================================================
# binutils
# ============================================================================

binutils: $(STAMP_BINUTILS)

$(STAMP_BINUTILS): | prereqs
	@mkdir -p $(BUILD_DIR) $(STAMP_DIR)
	@echo "=== Downloading binutils $(BINUTILS_VER) ==="
	wget -q $(BINUTILS_URL) -O $(BUILD_DIR)/binutils.tar.gz
	@echo "=== Extracting binutils ==="
	tar xzf $(BUILD_DIR)/binutils.tar.gz -C $(BUILD_DIR)
	rm $(BUILD_DIR)/binutils.tar.gz
	@echo "=== Configuring binutils ==="
	cd $(BINUTILS_SRC) && ./configure \
		--prefix=$(INSTALL_DIR) \
		--target=m68k-elf \
		--with-newlib \
		--disable-plugins \
		--disable-werror \
		--disable-nls
	@echo "=== Building binutils ==="
	$(MAKE) -j$(JOBS) -C $(BINUTILS_SRC)
	$(MAKE) install -C $(BINUTILS_SRC)
	rm -rf $(BINUTILS_SRC)
	@touch $@
	@echo "=== binutils done ==="

# ============================================================================
# GCC stage 1 (compiler only, no libgcc yet — needs newlib headers first)
# ============================================================================

gcc-stage1: $(STAMP_GCC1)

$(STAMP_GCC1): $(STAMP_BINUTILS)
	@echo "=== Downloading GCC $(GCC_VER) ==="
	wget -q $(GCC_URL) -O $(BUILD_DIR)/gcc.tar.gz
	@echo "=== Extracting GCC ==="
	tar xzf $(BUILD_DIR)/gcc.tar.gz -C $(BUILD_DIR)
	rm $(BUILD_DIR)/gcc.tar.gz
	@echo "=== Downloading GCC prerequisites ==="
	cd $(GCC_SRC) && contrib/download_prerequisites
	@echo "=== Configuring GCC ==="
	mkdir -p $(GCC_BUILD)
	cd $(GCC_BUILD) && $(GCC_SRC)/configure \
		--prefix=$(INSTALL_DIR) \
		--target=m68k-elf \
		--with-cpu=68000 \
		--enable-languages=c,c++ \
		--disable-libssp \
		--disable-nls \
		--disable-multilib \
		--disable-werror \
		--with-newlib \
		CFLAGS_FOR_TARGET="-mcpu=68000" \
		CXXFLAGS_FOR_TARGET="-mcpu=68000"
	@echo "=== Building GCC (stage 1) ==="
	$(MAKE) all-gcc -j$(JOBS) -C $(GCC_BUILD)
	$(MAKE) install-gcc -C $(GCC_BUILD)
	@touch $@
	@echo "=== GCC stage 1 done ==="

# ============================================================================
# newlib + Merlin 2 BSP
# ============================================================================

newlib: $(STAMP_NEWLIB)

$(STAMP_NEWLIB): $(STAMP_GCC1)
	@echo "=== Downloading newlib $(NEWLIB_VER) ==="
	wget -q $(NEWLIB_URL) -O $(BUILD_DIR)/newlib.tar.gz
	@echo "=== Extracting newlib ==="
	tar xzf $(BUILD_DIR)/newlib.tar.gz -C $(BUILD_DIR)
	rm $(BUILD_DIR)/newlib.tar.gz
	@echo "=== Installing Merlin 2 BSP files ==="
	cp $(BSP_DIR)/merlin2.S $(NEWLIB_SRC)/libgloss/m68k/
	cp $(BSP_DIR)/merlin2.h $(NEWLIB_SRC)/libgloss/m68k/
	cp $(BSP_DIR)/merlin2.ld $(NEWLIB_SRC)/libgloss/m68k/
	cp $(BSP_DIR)/crt0.S $(NEWLIB_SRC)/libgloss/m68k/crt0-68000.S
	@echo "=== Patching Makefile.in for Merlin 2 board ==="
	sed -i 's/\r$$//' $(NEWLIB_SRC)/libgloss/m68k/Makefile.in
	cd $(NEWLIB_SRC)/libgloss/m68k && \
	patch -p1 < $(BSP_DIR)/merlin2-makefile.patch
	@echo "=== Configuring newlib ==="
	mkdir -p $(NEWLIB_BUILD)
	cd $(NEWLIB_BUILD) && $(NEWLIB_SRC)/configure \
		--prefix=$(INSTALL_DIR) \
		--target=m68k-elf \
		--enable-newlib-nano-malloc \
		--enable-lite-exit \
		--disable-newlib-supplied-syscalls \
		--disable-newlib-wide-orient \
		--disable-libssp \
		--disable-nls \
		--disable-multilib \
		CFLAGS_FOR_TARGET="-mcpu=68000 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=return-mismatch"
	@echo "=== Building newlib ==="
	$(MAKE) -j$(JOBS) -C $(NEWLIB_BUILD)
	@echo "=== Installing newlib ==="
	$(MAKE) install -C $(NEWLIB_BUILD)
	@touch $@
	@echo "=== newlib + Merlin 2 BSP done ==="

# ============================================================================
# GCC libgcc rebuild (now that newlib is installed)
# ============================================================================

gcc-libgcc: $(STAMP_LIBGCC)

$(STAMP_LIBGCC): $(STAMP_NEWLIB)
	@echo "=== Building libgcc ==="
	$(MAKE) all-target-libgcc -j$(JOBS) -C $(GCC_BUILD) CFLAGS_FOR_TARGET="-mcpu=68000"
	$(MAKE) install-target-libgcc -C $(GCC_BUILD)
	@echo "=== Cleaning up build directories ==="
	rm -rf $(GCC_SRC) $(GCC_BUILD) $(NEWLIB_SRC) $(NEWLIB_BUILD)
	@touch $@
	@echo "=== libgcc done ==="

# ============================================================================
# Examples
# ============================================================================

examples:
	@if ! which m68k-elf-gcc >/dev/null 2>&1; then \
		echo "ERROR: m68k-elf-gcc not in PATH. Run 'make all' first."; \
		exit 1; \
	fi
	$(MAKE) -C examples

# ============================================================================
# Clean
# ============================================================================

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C examples clean
