#!/bin/bash

# Exit on any error
set -e

# Source library path and name
SRC_LIB="../src/sde_lib/lib/so/libsde.so.1.0.0"

# Check if source library exists
if [ ! -f "$SRC_LIB" ]; then
    echo "Error: Source library $SRC_LIB not found"
    exit 1
fi

# Find appropriate library installation directory
if [ -d "/usr/local/lib64" ]; then
    LIB_DST_DIR=/usr/local/lib64
elif [ -d "/usr/local/lib" ]; then
    LIB_DST_DIR=/usr/local/lib
elif [ -d "/usr/lib64" ]; then
    LIB_DST_DIR=/usr/lib64
elif [ -d "/usr/lib" ]; then
    LIB_DST_DIR=/usr/lib
else
    echo "Error: No directory for installing libraries."
    exit 1
fi

echo "Installing to $LIB_DST_DIR"

# Check if we have sudo rights
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Copy library file
cp "$SRC_LIB" "$LIB_DST_DIR/"

# Create symbolic links
cd "$LIB_DST_DIR"
ln -sf libsde.so.1.0.0 libsde.so.1
ln -sf libsde.so.1 libsde.so

# Update library cache
ldconfig

echo "Library installation complete"
