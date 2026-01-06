#!/usr/bin/env bash

set -euo pipefail

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if running on NixOS
if [ -f /etc/NIXOS ]; then
    log_warn "Running on NixOS - some steps may be different"
fi

# Step 1: Install Nix if not already installed
if command -v nix &> /dev/null; then
    log_info "Nix is already installed ($(nix --version))"
else
    log_info "Installing Nix via Determinate Systems installer..."
    if ! curl -fsSL https://install.determinate.systems/nix | sh -s -- install; then
        log_error "Failed to install Nix"
        exit 1
    fi
    
    # Source nix profile to make nix command available
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        log_info "Sourcing nix profile..."
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    
    log_info "Nix installed successfully"
fi

# Step 2: Initialize home-manager if not already configured
if [ ! -d "$HOME/.config/home-manager" ]; then
    log_info "Initializing home-manager..."
    if ! nix run home-manager/release-25.05 -- init --switch; then
        log_error "Failed to initialize home-manager"
        exit 1
    fi
    log_info "home-manager initialized successfully"
else
    log_info "home-manager configuration directory already exists"
fi

# Step 3: Switch to the nixos-config flake
log_info "Switching to nixos-config flake from GitHub..."
if ! home-manager switch --flake github:sspeaks/nixos-config#sspeaks@NixOS-WSL; then
    log_error "Failed to switch home-manager configuration"
    log_warn "You may need to manually resolve conflicts in ~/.config/home-manager"
    exit 1
fi

log_info "Bootstrap completed successfully!"
log_info "You may need to restart your shell or source your shell configuration"
