# Project Configuration & Directory Paths
APP_NAME  = bls
SRC_DIR   = src
INC_DIR   = include
BUILD_DIR = build
BIN_DIR   = bin
FORMAT    = elf64
CMDS      = all build run clean

# Makefile Directives
.SILENT: $(CMDS)  # Suppress command echoing during execution
.PHONY: $(CMDS)   # Declare targets as abstract commands rather than physical files

# Reusable Build Macro Definitions
# Macro to compile x86_64 Assembly source files using NASM
define assembler
	nasm -f $(FORMAT) $(1) -o $(2)
endef

# Macro to link compiled object files using LD
define linker
	ld $(1) -o $(2)
endef

# Build and Execution Targets
# Default target that triggers the project compilation
all: build

# Core build system: initializes directories, compiles source files, and links the binary
build: 
	@ { \
		[ ! -d $(BUILD_DIR) ] && mkdir $(BUILD_DIR); \
		[ ! -d $(BIN_DIR) ] && mkdir $(BIN_DIR); \
		for asmf in $$( \
			find ./$(SRC_DIR) ./$(INC_DIR) \
			-type f \( -name "*.asm" -o -name "*.inc" \) \
		); do \
			fname=$$(basename $$asmf); \
			$(call assembler,$$asmf,$(BUILD_DIR)/$${fname%.*}.o); \
		done; \
		$(call linker,$(BUILD_DIR)/*,$(BIN_DIR)/$(APP_NAME)); \
	}

# Dependency-driven target to build and execute the binary
run: build
	@./$(BIN_DIR)/$(APP_NAME)

# Cleanup target to remove build artifacts and generated binaries
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)