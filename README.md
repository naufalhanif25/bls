# bls - Assembly Directory Lister

## Description

`bls` (short for **bare ls**) is a high-performance, lightweight command-line directory listing utility written entirely in x86_64 Assembly for Linux systems. Designed as a bare-metal alternative to standard listing tools, it interacts directly with the Linux kernel via system calls (`syscall`) without linking to the standard C library (glibc). This architectural approach ensures a minimal binary footprint and optimal execution speed.

The application leverages the `sys_getdents64` system call to read raw directory entries into a localized buffer, which are then parsed and formatted for standard output. It supports essential operational flags including dynamic help menu generation, version information display, and a dedicated flag to toggle the visibility of hidden files.

## Prerequisites

To compile and execute this project, the following components must be installed on your Linux system:
* **Operating System**: Linux x86_64 (64-bit architecture)
* **Assembler**: Netwide Assembler (NASM) version 2.15 or later
* **Linker**: GNU Linker (LD) from GNU Binutils
* **Build Automation**: GNU Make

## Getting Started

### 1. Clone the Repository

Clone the project repository from GitHub to your local machine using the following command:

```bash
git clone https://github.com/naufalhanif25/bls.git
```

### 2. Navigate to the Project Directory

Change your current working directory to the newly cloned repository:

```bash
cd bls
```

### 3. Build the Target Binary

Compile the source code and generate the executable binary by running the build target defined in the Makefile:

```bash
make build
```

This process automatically initializes the `build/` and `bin/` directories, compiles the assembly files using NASM, and links the resulting object files into a standalone executable.

### 4. Run the Application

Execute the compiled binary directly through the automation script:

```bash
make run
```

### 5. Clean Build Artifacts

To remove all temporary object files, build caches, and the generated binaries, execute the cleanup command:

```bash
make clean
```

## Project Structure

Below is an overview of the directory layout within the repository:

```text
.
├── bin/          # Directory containing the final executable binary
├── build/        # Directory for temporary compiled object (.o) files
├── include/      # Assembly header and definition files (.inc)
├── src/          # Core assembly source files (.asm)
├── .gitignore    # Git tracking exclusion list
├── LICENSE       # Legal terms and distribution permissions (MIT)
├── Makefile      # GNU Make build automation configuration
└── README.md     # Project documentation and usage guide
```

## License

This project is licensed under the terms of the MIT License. It permits free and unrestricted use, modification, distribution, and sublicensing of the software, provided that the original copyright notice and permission terms are included in all copies or substantial portions of the software.