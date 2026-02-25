#!/bin/bash

# Backup files and directories to a specified location with advanced features

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
readonly TEMP_DIR=$(mktemp -d)

trap cleanup EXIT INT TERM
cleanup() {
  rm -rf "$TEMP_DIR"
  rm -f "$LOCK_FILE"
}

# Create lock file to prevent concurrent backups
if [ -f "$LOCK_FILE" ]; then
  echo "Error: Another backup is already running (lock file exists)"
  exit 1
fi
touch "$LOCK_FILE"

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] SOURCE DESTINATION

Backup files and directories to a specified location with compression,
timestamping, verification, and rotation support.

OPTIONS:
    -h, --help              Show this help message
    -c, --compress          Compress backup using tar.gz
    -t, --timestamp         Add timestamp to backup name
    -v, --verbose           Verbose output
    -d, --dry-run           Show what would be done without executing
    -e, --exclude PATTERN   Exclude files matching PATTERN (can be used multiple times)
    -r, --retain NUM        Keep only NUM most recent backups (rotation)
    -s, --verify            Verify backup integrity after creation
    --hash ALGO             Generate hash checksum (md5, sha256, sha512)

EXAMPLES:
    $SCRIPT_NAME /home/user/documents /backup/location
    $SCRIPT_NAME -ct /etc /backup/config
    $SCRIPT_NAME -cte '*.log' -e '*.tmp' /home/user /backup/location
    $SCRIPT_NAME -ctsr 5 --hash sha256 /home/user /backup/location

EOF
}

log_verbose() {
  [ "$VERBOSE" = true ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*" >&2
}

log_error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_success() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*"
}

# Initialize variables
COMPRESS=false
TIMESTAMP=false
VERBOSE=false
DRY_RUN=false
VERIFY=false
RETAIN=0
HASH_ALGO=""
declare -a EXCLUDE_PATTERNS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      show_help
      exit 0
      ;; 
    -c | --compress)
      COMPRESS=true
      shift
      ;;  
    -t | --timestamp)
      TIMESTAMP=true
      shift
      ;;  
    -v | --verbose)
      VERBOSE=true
      shift
      ;;  
    -d | --dry-run)
      DRY_RUN=true
      VERBOSE=true
      shift
      ;;  
    -s | --verify)
      VERIFY=true
      shift
      ;;  
    -e | --exclude)
      EXCLUDE_PATTERNS+=("$2")
      shift 2
      ;;  
    -r | --retain)
      RETAIN="$2"
      shift 2
      ;;  
    --hash)
      HASH_ALGO="$2"
      shift 2
      ;;  
    -* )
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;  
    *)
      break
      ;;  
  esac
done

# Validate required arguments
if [ $# -lt 2 ]; then
  log_error "SOURCE and DESTINATION are required"
  show_help
  exit 1
fi

SOURCE="$1"
DESTINATION="$2"

# Resolve to absolute paths
SOURCE=$(cd "
$(dirname "$SOURCE")" && pwd)/$(basename "$SOURCE")
DESTINATION=$(cd "$(dirname "$DESTINATION")" && pwd)

# Validate source exists and is readable
if [ ! -e "$SOURCE" ]; then
  log_error "Source '$SOURCE' does not exist"
  exit 1
fi

if [ ! -r "$SOURCE" ]; then
  log_error "Source '$SOURCE' is not readable"
  exit 1
fi

# Validate destination exists and is writable
if [ ! -d "$DESTINATION" ]; then
  log_error "Destination directory '$DESTINATION' does not exist"
  exit 1
fi

if [ ! -w "$DESTINATION" ]; then
  log_error "Destination directory '$DESTINATION' is not writable"
  exit 1
fi

# Validate hash algorithm if specified
if [ -n "$HASH_ALGO" ]; then
  if ! command -v "${HASH_ALGO}sum" &> /dev/null; then
    log_error "Hash algorithm '${HASH_ALGO}sum' not found"
    exit 1
  fi
fi

# Validate retain number
if [ "$RETAIN" -gt 0 ] && ! [[ "$RETAIN" =~ ^[0-9]+$ ]]; then
  log_error "Retain value must be a positive integer"
  exit 1
fi

log_verbose "Source: $SOURCE"
log_verbose "Destination: $DESTINATION"
[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ] && log_verbose "Exclude patterns: ${EXCLUDE_PATTERNS[*]}"

BACKUP_NAME=$(basename "$SOURCE")

if [ "$TIMESTAMP" = true ]; then
  TIMESTAMP_STR=$(date +%Y%m%d_%H%M%S)
  BACKUP_NAME="${BACKUP_NAME}_${TIMESTAMP_STR}"
fi

# Build tar exclude options
declare -a TAR_EXCLUDE_OPTS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  TAR_EXCLUDE_OPTS+=(--exclude="$pattern")
done

# Function to get backup size
get_size() {
  if [ -d "$1" ]; then
    du -sh "$1" | cut -f1
  elif [ -f "$1" ]; then
    ls -lh "$1" | awk '{print $5}'
  fi
}

# Function to generate hash
generate_hash() {
  local file="$1"
  if [ -n "$HASH_ALGO" ]; then
    "${HASH_ALGO}sum" "$file" > "${file}.${HASH_ALGO}"
    log_verbose "Generated ${HASH_ALGO} hash: $(cat "${file}.${HASH_ALGO}")"
  fi
}

# Function to verify backup
verify_backup() {
  local backup_file="$1"
  
  if [ -n "$HASH_ALGO" ] && [ -f "${backup_file}.${HASH_ALGO}" ]; then
    log_verbose "Verifying backup integrity using ${HASH_ALGO}..."
    if "${HASH_ALGO}sum" -c "${backup_file}.${HASH_ALGO}" &> /dev/null; then
      log_verbose "Backup verification successful"
      return 0
    else
      log_error "Backup verification failed!"
      return 1
    fi
  elif [ "$COMPRESS" = true ]; then
    log_verbose "Verifying tar.gz integrity..."
    if tar -tzf "$backup_file" &> /dev/null; then
      log_verbose "Backup verification successful"
      return 0
    else
      log_error "Backup verification failed!"
      return 1
    fi
  fi
  return 0
}

# Function to clean up old backups
rotate_backups() {
  local pattern="$1"
  local count="$2"
  
  if [ "$count" -le 0 ]; then
    return
  fi  
  
  log_verbose "Rotating backups, keeping $count most recent..."
  
  # Find backups matching pattern, sort by time, keep newest N
  while IFS= read -r backup; do
    if [ "$DRY_RUN" = true ]; then
      log_verbose "Would delete: $backup"
    else
      log_verbose "Deleting old backup: $backup"
      rm -rf "$backup"*
    fi
  done < <(ls -1t "$DESTINATION"/${pattern}* 2>/dev/null | tail -n +$((count + 1)))
}

# Perform backup
if [ "$DRY_RUN" = true ]; then
  log_verbose "DRY RUN MODE - No changes will be made"
fi

if [ "$COMPRESS" = true ]; then
  BACKUP_FILE="${DESTINATION}/${BACKUP_NAME}.tar.gz"
  
  log_verbose "Creating compressed backup: $BACKUP_FILE"
  [ "$VERBOSE" = true ] && echo "Source size: $(get_size "$SOURCE")"
  
  if [ "$DRY_RUN" = false ]; then
    if tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE")" "${TAR_EXCLUDE_OPTS[@]}" "$(basename "$SOURCE")"; then
      generate_hash "$BACKUP_FILE"
      log_success "Backup created: $BACKUP_FILE ($(get_size "$BACKUP_FILE"))"
      
      if [ "$VERIFY" = true ]; then
        verify_backup "$BACKUP_FILE" || exit 1
      fi
    else
      log_error "Failed to create compressed backup"
      rm -f "$BACKUP_FILE"
      exit 1
    fi
  else
    echo "[DRY RUN] Would create: tar -czf $BACKUP_FILE -C $(dirname "$SOURCE") ${TAR_EXCLUDE_OPTS[@]} $(basename "$SOURCE")"
  fi
else
  BACKUP_PATH="${DESTINATION}/${BACKUP_NAME}"
  
  log_verbose "Copying to: $BACKUP_PATH"
  [ "$VERBOSE" = true ] && echo "Source size: $(get_size "$SOURCE")"
  
  if [ "$DRY_RUN" = false ]; then
    # Use -a flag for archive mode (preserves permissions, timestamps, ownership)
    if cp -a "$SOURCE" "$BACKUP_PATH"; then
      log_success "Backup created: $BACKUP_PATH ($(get_size "$BACKUP_PATH"))"
      
      if [ "$VERIFY" = true ]; then
        verify_backup "$BACKUP_PATH" || exit 1
      fi
    else
      log_error "Failed to create backup"
      rm -rf "$BACKUP_PATH"
      exit 1
    fi
  else
    echo "[DRY RUN] Would copy: cp -a $SOURCE $BACKUP_PATH"
  fi
fi

# Handle backup rotation
if [ "$RETAIN" -gt 0 ] && [ "$DRY_RUN" = false ]; then
  rotate_backups "$BACKUP_NAME" "$RETAIN"
fi

log_verbose "Backup process completed successfully"