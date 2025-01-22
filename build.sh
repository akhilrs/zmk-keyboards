#!/bin/bash

# Set up the environment variables
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="$HOME/zephyr-sdk"
export ZEPHYR_BASE="$(pwd)/zmk/zephyr"

# Initialize workspace if not already done
init_workspace() {
    if [ ! -d "zmk" ]; then
        echo "Initializing ZMK workspace..."
        cd config
        west init -l .
        west update
        cd ..
    fi
    
    # Setup Python virtual environment
    if [ ! -d ".venv" ]; then
        echo "Setting up Python virtual environment..."
        python3 -m venv .venv
        source .venv/bin/activate
        pip install -U pip
        pip install west cmake ninja
    else
        source .venv/bin/activate
    fi
    
    # Source Zephyr environment
    if [ -f "zmk/zephyr/zephyr-env.sh" ]; then
        source zmk/zephyr/zephyr-env.sh
    fi
    
    # Install Python dependencies
    pip install -r zmk/zephyr/scripts/requirements.txt
    
    # Install west requirements
    west update
}

# Create build directory if it doesn't exist
mkdir -p build

# Function to build firmware
build_firmware() {
    local side=$1
    local build_dir="build/${side}"
    
    echo "Building ${side} firmware..."
    
    # Create side-specific build directory
    mkdir -p "$build_dir"
    
    # Source environment
    source .venv/bin/activate
    
    if [ "$side" == "left" ]; then
        west build -p -s zmk/app -d "$build_dir" -b nice_nano_v2 -- \
            -DSHIELD="acorn_central_left nice_view_adapter nice_view" \
            -DZMK_CONFIG="$(pwd)/config"
    elif [ "$side" == "right" ]; then
        west build -p -s zmk/app -d "$build_dir" -b nice_nano_v2 -- \
            -DSHIELD="acorn_peripheral_right nice_view_adapter nice_view" \
            -DZMK_CONFIG="$(pwd)/config"
    fi
    
    if [ $? -eq 0 ]; then
        echo "Build successful for ${side} side!"
        # Copy the firmware file to an easy-to-find location
        cp "$build_dir/zephyr/zmk.uf2" "./build/${side}_firmware.uf2"
        echo "Firmware saved as: build/${side}_firmware.uf2"
    else
        echo "Build failed for ${side} side!"
        exit 1
    fi
}

# Initialize workspace
init_workspace

# Check if an argument was provided
if [ "$1" == "left" ] || [ "$1" == "right" ]; then
    build_firmware "$1"
elif [ "$1" == "both" ]; then
    build_firmware "left"
    build_firmware "right"
else
    echo "Usage: ./build.sh [left|right|both]"
    echo "Example: ./build.sh left - Builds left side only"
    echo "         ./build.sh right - Builds right side only"
    echo "         ./build.sh both - Builds both sides"
    exit 1
fi
