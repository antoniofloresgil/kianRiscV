# Use the official Ubuntu base image
FROM ubuntu:20.04
# FROM ghcr.io/hdl/containers/eda:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    vim \
    sudo \
    libgtk2.0-0 \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    libx11-dev \
    libxext-dev \
    libxft-dev \
    libxinerama-dev \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    verilator \
    gtkwave \
    && apt-get clean

# Create a non-root user
RUN useradd -ms /bin/bash devuser && echo "devuser:devuser" | chpasswd && adduser devuser sudo

# Set the user to "devuser"
USER devuser
WORKDIR /home/devuser

# Install VS Code extensions for SystemVerilog
RUN mkdir -p /home/devuser/.vscode-server/extensions
RUN code --install-extension mshr-h.veriloghdl

# Set up entrypoint
ENTRYPOINT ["/bin/bash"]