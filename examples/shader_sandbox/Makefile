# =============================================================================
# CrShader Live Sandbox Makefile
# =============================================================================

ifeq ($(OS),Windows_NT)
	PLATFORM        = windows
	SO_EXT          = dll
	EXE_EXT         = .exe
	GODOT           ?= $(if $(wildcard ../../../../godot.exe),../../../../godot.exe,$(if $(wildcard ../../../godot.exe),../../../godot.exe,godot.exe))
	LINK_FLAGS      ?= /DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init
else
	UNAME_S := $(shell uname -s 2>/dev/null)
	ifeq ($(UNAME_S),Darwin)
		PLATFORM        = macos
		SO_EXT          = dylib
		EXE_EXT         =
		GODOT           ?= $(if $(wildcard ../../../../godot),../../../../godot,$(if $(wildcard ../../../godot),../../../godot,godot))
		LINK_FLAGS      ?= -dynamiclib
	else
		PLATFORM        = linux
		SO_EXT          = so
		EXE_EXT         =
		GODOT           ?= $(if $(wildcard ../../../../godot),../../../../godot,$(if $(wildcard ../../../godot),../../../godot,godot))
		LINK_FLAGS      ?= -shared
	endif
endif

ENTRY           ?= src/main.cr
LAPIS           ?= $(if $(wildcard ../../../../bin/lapis$(EXE_EXT)),../../../../bin/lapis$(EXE_EXT),$(if $(wildcard ../../../bin/lapis$(EXE_EXT)),../../../bin/lapis$(EXE_EXT),$(if $(wildcard ./bin/lapis$(EXE_EXT)),./bin/lapis$(EXE_EXT),lapis$(EXE_EXT))))
SOURCE_DIR      ?= $(if $(wildcard ../../../../src),../../../../src,lib)

BIN_DIR         = bin
DIST_DIR        = dist
GAME_LIB        = $(BIN_DIR)/game.$(SO_EXT)
GAME_EXE        = $(BIN_DIR)/game$(EXE_EXT)

CRYSTAL_FLAGS   =
ifeq ($(strip $(RELEASE)),1)
	CRYSTAL_FLAGS += --release
endif

.PHONY: all dirs deps bridge extension_list addons build game_dll game_exe package run editor clean help

all: dirs deps bridge extension_list addons game_dll
	@echo ===================================================================
	@echo   CRShader Live Sandbox built successfully!
	@echo   Run 'make run' to launch or 'make package' to create distributable.
	@echo ===================================================================

dirs:
	@$(LAPIS) dirs

deps: dirs
	@$(LAPIS) deps -t $(BIN_DIR)

bridge: dirs
	@$(LAPIS) sync

extension_list: dirs
	@$(LAPIS) sync

addons: dirs
	@$(LAPIS) sync --addons-only

build game_dll: dirs deps bridge extension_list addons
	@echo [Sandbox] Compiling game.$(SO_EXT) from $(ENTRY)...
	@$(LAPIS) build -e $(ENTRY) -o $(GAME_LIB) -l '$(LINK_FLAGS)' $(if $(filter 1,$(RELEASE)),-r,) -s $(SOURCE_DIR)
	@$(LAPIS) sync

game_exe: dirs deps bridge extension_list addons game_dll
	@echo [Sandbox] Packaging complete playable game executable...
	@$(LAPIS) package game -p . -n sandbox-$(PLATFORM) $(if $(filter 1,$(RELEASE)),-r,)

package: game_dll
	@echo [Sandbox] Packaging Standalone Shader Sandbox archive...
	@$(LAPIS) package game -p . -n sandbox-$(PLATFORM) $(if $(filter 1,$(RELEASE)),-r,) -t $(DIST_DIR) -f
	@$(if $(filter Windows_NT,$(OS)),powershell -Command "Compress-Archive -Path $(DIST_DIR)/sandbox-$(PLATFORM)/* -DestinationPath $(DIST_DIR)/sandbox-$(PLATFORM).zip -Force",(cd $(DIST_DIR)/sandbox-$(PLATFORM) && zip -r ../sandbox-$(PLATFORM).zip ./*))

run: all
	@echo [Sandbox] Launching Shader Sandbox with $(GODOT)...
	$(GODOT) --path .

editor: all
	@echo [Sandbox] Opening Shader Sandbox in Godot Editor...
	$(GODOT) --editor --path .

clean:
	@$(if $(filter Windows_NT,$(OS)),powershell -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue bin, dist, .godot",rm -rf $(BIN_DIR) $(DIST_DIR) .godot)

help:
	@echo CrShader Sandbox Targets:
	@echo   make all      - Build sandbox game library and sync dependencies
	@echo   make build    - Compile Crystal game library
	@echo   make package  - Create standalone sandbox-$(PLATFORM).zip in dist/
	@echo   make run      - Launch interactive sandbox in Godot
	@echo   make editor   - Open project in Godot Editor
	@echo   make clean    - Remove build artifacts
