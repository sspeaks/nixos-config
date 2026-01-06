#!/usr/bin/env bash
{ # Wrap entire script to ensure it's fully downloaded before execution

# Ensure HOME and USER are set (needed when piped from curl)
# MUST be done before set -u
if [ -z "${HOME:-}" ]; then
    HOME=$(getent passwd "$(whoami)" | cut -d: -f6)
fi
if [ -z "${USER:-}" ]; then
    USER=$(whoami)
fi
export HOME USER

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

# Step 4: Set zsh as default shell
HM_ZSH="${HOME}/.nix-profile/bin/zsh"
if [ -f "$HM_ZSH" ]; then
    CURRENT_SHELL=$(getent passwd "${USER}" 2>/dev/null | cut -d: -f7 || echo "")
    
    if [ -n "$CURRENT_SHELL" ] && [ "$CURRENT_SHELL" != "$HM_ZSH" ]; then
        # Add home-manager zsh to /etc/shells if not already there
        if ! grep -q "^$HM_ZSH$" /etc/shells 2>/dev/null; then
            log_info "Adding $HM_ZSH to /etc/shells..."
            if command -v sudo &> /dev/null; then
                if echo "$HM_ZSH" | sudo tee -a /etc/shells > /dev/null 2>&1; then
                    log_info "Added to /etc/shells successfully"
                else
                    log_warn "Failed to add to /etc/shells, you may need to do this manually"
                fi
            else
                log_warn "sudo not available, you'll need to manually add $HM_ZSH to /etc/shells"
            fi
        fi
        
        # Try to change shell - works with passwordless sudo or if stdin is a terminal
        log_info "Attempting to change default shell to zsh..."
        if command -v chsh &> /dev/null; then
            # Try with sudo first (works on WSL with no password)
            if sudo -n chsh -s "$HM_ZSH" "$USER" 2>/dev/null; then
                log_info "Default shell changed to zsh successfully"
            # Try regular chsh (works if user can authenticate)
            elif echo "" | chsh -s "$HM_ZSH" 2>/dev/null; then
                log_info "Default shell changed to zsh successfully"
            else
                log_warn "Could not change shell automatically (may require password)"
                log_warn "Run this command manually: chsh -s $HM_ZSH"
            fi
        else
            log_warn "chsh not available. Manually set shell to: $HM_ZSH"
        fi
    elif [ -z "$CURRENT_SHELL" ]; then
        log_warn "Could not determine current shell, skipping shell change"
        log_info "To manually change shell, run: chsh -s $HM_ZSH"
    else
        log_info "Default shell is already set to home-manager zsh"
    fi
else
    log_warn "home-manager zsh not found at $HM_ZSH"
fi

log_info "Bootstrap completed successfully!"
log_info "You may need to log out and log back in for shell changes to take effect"

exit 0
} # End of wrapped script - ensures full download before execution
