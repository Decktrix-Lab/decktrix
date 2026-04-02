FROM ubuntu:noble

# Install all required build dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    wget \
    bc \
    bison \
    build-essential \
    flex \
    libgnutls28-dev \
    libssl-dev \
    python3-dev \
    python3-minimal \
    python3-setuptools \
    swig \
    uuid-dev \
    python3-cryptography \
    python3-pyelftools \
    device-tree-compiler \
    dosfstools \
    genimage \
    mtools \
    debootstrap \
    qemu-user-static \
    git \
    make \
    gcc \
    g++ \
    cpio \
    kmod \
    libncurses-dev \
    libelf-dev \
    pkg-config \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for building (optional)
RUN useradd -m -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/builder

# Set working directory
WORKDIR /workspace

# Copy build script and toolchain
COPY build-image.sh /workspace/
COPY toolchain /workspace/toolchain

# Extract toolchain if present
RUN mkdir -p toolchain/extracted && \
    if [ -f toolchain/x86_64-gcc-11.3.0-nolibc-arm-linux-gnueabi.tar.xz ]; then \
        tar -xf toolchain/x86_64-gcc-11.3.0-nolibc-arm-linux-gnueabi.tar.xz -C toolchain/extracted; \
    fi

# Default command: show help
CMD ["/bin/bash", "-c", "echo 'To build an SD card image, run:' && echo '  docker run -v \$(pwd):/workspace -w /workspace <image> ./build-image.sh <variant>' && echo 'Variants: stm32, stm32-jadard'"]