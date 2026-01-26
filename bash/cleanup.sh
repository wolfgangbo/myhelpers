#!/bin/bash

# Clean up temporary files and directories

set -e

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Clean up temporary files and directories.

OPTIONS:
    -h, --help          Show this help message
    -a, --all           Clean all temp locations (system + user)
    -s, --system        Clean system temp directories (requires sudo)
    -u, --user          Clean user temp directories
    -d, --dry-run       Show what would be deleted without deleting
    -v, --verbose       Verbose output

EXAMPLES:
    $(basename "$0") --user
    $(basename "$0") --all --dry-run
    $(basename "$0") -sv
EOF
}

CLEAN_SYSTEM=false
CLEAN_USER=false
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      show_help
      exit 0
      ;;
    -a | --all)
      CLEAN_SYSTEM=true
      CLEAN_USER=true
      shift
      ;;
    -s | --system)
      CLEAN_SYSTEM=true
      shift
      ;;
    -u | --user)
      CLEAN_USER=true
      shift
      ;;
    -d | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

if [ "$CLEAN_SYSTEM" = false ] && [ "$CLEAN_USER" = false ]; then
  CLEAN_USER=true
fi

cleanup_directory() {
  local dir="$1"
  local description="$2"

  if [ ! -d "$dir" ]; then
    [ "$VERBOSE" = true ] && echo "Skipping $description: Directory does not exist"
    return
  fi

  echo "Cleaning $description: $dir"

  if [ "$DRY_RUN" = true ]; then
    find "$dir" -type f -mtime +7 2>/dev/null | while read -r file; do
      echo "[DRY RUN] Would delete: $file"
    done
  else
    local count
    count=$(find "$dir" -type f -mtime +7 2>/dev/null | wc -l)
    find "$dir" -type f -mtime +7 -delete 2>/dev/null
    echo "Deleted $count file(s) older than 7 days"
  fi
}

if [ "$CLEAN_USER" = true ]; then
  echo "=== Cleaning user temporary files ==="
  cleanup_directory "$HOME/.cache" "User cache"
  cleanup_directory "/tmp" "Temporary directory"
  cleanup_directory "$HOME/Downloads" "Downloads (old files)"
fi

if [ "$CLEAN_SYSTEM" = true ]; then
  echo "=== Cleaning system temporary files ==="
  if [ "$EUID" -ne 0 ]; then
    echo "Warning: System cleanup requires sudo privileges"
    exit 1
  fi
  cleanup_directory "/var/tmp" "System temp"
  cleanup_directory "/var/log" "Old logs"
fi

echo "Cleanup complete!"
