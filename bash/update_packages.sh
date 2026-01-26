#!/bin/bash

# Update system packages and dependencies

set -e

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Update system packages and dependencies.

OPTIONS:
    -h, --help          Show this help message
    -a, --auto          Auto-confirm updates (no prompts)
    -c, --clean         Clean package cache after update
    -v, --verbose       Verbose output

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --auto --clean
EOF
}

AUTO_CONFIRM=false
CLEAN_CACHE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      show_help
      exit 0
      ;;
    -a | --auto)
      AUTO_CONFIRM=true
      shift
      ;;
    -c | --clean)
      CLEAN_CACHE=true
      shift
      ;;
    -v | --verbose)
      export VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

detect_package_manager() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v yum &>/dev/null; then
    echo "yum"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  elif command -v zypper &>/dev/null; then
    echo "zypper"
  else
    echo "unknown"
  fi
}

PKG_MANAGER=$(detect_package_manager)

if [ "$PKG_MANAGER" = "unknown" ]; then
  echo "Error: No supported package manager found"
  exit 1
fi

echo "Detected package manager: $PKG_MANAGER"
echo "=================================="

case $PKG_MANAGER in
  apt)
    echo "Updating package lists..."
    sudo apt-get update

    if [ "$AUTO_CONFIRM" = true ]; then
      echo "Upgrading packages..."
      sudo apt-get upgrade -y
      sudo apt-get dist-upgrade -y
    else
      echo "Upgrading packages..."
      sudo apt-get upgrade
      sudo apt-get dist-upgrade
    fi

    if [ "$CLEAN_CACHE" = true ]; then
      echo "Cleaning package cache..."
      sudo apt-get autoclean
      sudo apt-get autoremove -y
    fi
    ;;

  dnf)
    if [ "$AUTO_CONFIRM" = true ]; then
      sudo dnf upgrade -y
    else
      sudo dnf upgrade
    fi

    if [ "$CLEAN_CACHE" = true ]; then
      sudo dnf clean all
      sudo dnf autoremove -y
    fi
    ;;

  yum)
    if [ "$AUTO_CONFIRM" = true ]; then
      sudo yum update -y
    else
      sudo yum update
    fi

    if [ "$CLEAN_CACHE" = true ]; then
      sudo yum clean all
      sudo yum autoremove -y
    fi
    ;;

  pacman)
    if [ "$AUTO_CONFIRM" = true ]; then
      sudo pacman -Syu --noconfirm
    else
      sudo pacman -Syu
    fi

    if [ "$CLEAN_CACHE" = true ]; then
      sudo pacman -Sc --noconfirm
    fi
    ;;

  zypper)
    if [ "$AUTO_CONFIRM" = true ]; then
      sudo zypper refresh
      sudo zypper update -y
    else
      sudo zypper refresh
      sudo zypper update
    fi

    if [ "$CLEAN_CACHE" = true ]; then
      sudo zypper clean
    fi
    ;;
esac

echo "=================================="
echo "Package update complete!"
