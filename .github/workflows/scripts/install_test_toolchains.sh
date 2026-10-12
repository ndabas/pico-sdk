#!/usr/bin/env bash
# Install a representative set of toolchains into /opt/arm and /opt/riscv, so
# multi_gcc_build.py can be tested on a GitHub-hosted runner. Not for use on
# the self-hosted runner, which already has the full set installed.
set -euo pipefail

INSTALL_ROOT=${INSTALL_ROOT:-/opt}

TOOLCHAINS=(
    # Oldest supported for Pico W
    "arm   gcc-arm-none-eabi-8-2018-q4-major                 https://developer.arm.com/-/media/Files/downloads/gnu-rm/8-2018q4/gcc-arm-none-eabi-8-2018-q4-major-linux.tar.bz2"
    # Oldest supported for RP2350
    "arm   gcc-arm-none-eabi-9-2019-q4-major                 https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2"
    "arm   arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi  https://developer.arm.com/-/media/Files/downloads/gnu/15.2.rel1/binrel/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-eabi.tar.xz"
    "arm   LLVMEmbeddedToolchainForArm-14.0.0                https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm/releases/download/release-14.0.0/LLVMEmbeddedToolchainForArm-14.0.0-linux.tar.gz"
    "arm   LLVM-ET-Arm-19.1.5-Linux-x86_64                   https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm/releases/download/release-19.1.5/LLVM-ET-Arm-19.1.5-Linux-x86_64.tar.xz"
    "riscv riscv32-unknown-elf-gcc-14.2.1                    https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.0.0-5/riscv-toolchain-14-x86_64-lin.tar.gz"
    "riscv gcc-riscv-32-pico-elf-16.1.0                      https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.3.1-0/riscv-toolchain-16-x86_64-lin.tar.gz"
)

install_one() {
    local dest=$1 url=$2
    local tmp
    tmp=$(mktemp -d)
    curl -fsSL --retry 3 -o "$tmp.archive" "$url"
    tar -xf "$tmp.archive" -C "$tmp"
    rm "$tmp.archive"
    # Some archives have a single top-level directory, others don't
    local entries=("$tmp"/*)
    if [ ${#entries[@]} -eq 1 ] && [ -d "${entries[0]}" ]; then
        mv "${entries[0]}" "$dest"
        rmdir "$tmp"
    else
        mv "$tmp" "$dest"
    fi
}

for root in arm riscv; do
    if ! mkdir -p "$INSTALL_ROOT/$root" 2>/dev/null; then
        sudo mkdir -p "$INSTALL_ROOT/$root"
        sudo chown "$(id -u):$(id -g)" "$INSTALL_ROOT/$root"
    fi
done

pids=()
for entry in "${TOOLCHAINS[@]}"; do
    read -r root name url <<< "$entry"
    dest="$INSTALL_ROOT/$root/$name"
    if [ -d "$dest" ]; then
        echo "Already installed: $dest"
        continue
    fi
    echo "Installing $dest from $url"
    install_one "$dest" "$url" &
    pids+=($!)
done

status=0
for pid in "${pids[@]}"; do
    wait "$pid" || status=1
done
exit $status
