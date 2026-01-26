#!/bin/bash

# Backup files and directories to a specified location

set -e

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] SOURCE DESTINATION

Backup files and directories to a specified location.

OPTIONS:
    -h, --help          Show this help message
    -c, --compress      Compress backup using tar.gz
    -t, --timestamp     Add timestamp to backup name
    -v, --verbose       Verbose output

EXAMPLES:
    $(basename "$0") /home/user/documents /backup/location
    $(basename "$0") -ct /etc /backup/config
EOF
}

COMPRESS=false
TIMESTAMP=false
VERBOSE=false

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
    -*)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -lt 2 ]; then
  echo "Error: SOURCE and DESTINATION are required"
  show_help
  exit 1
fi

SOURCE="$1"
DESTINATION="$2"

if [ ! -e "$SOURCE" ]; then
  echo "Error: Source '$SOURCE' does not exist"
  exit 1
fi

if [ ! -d "$DESTINATION" ]; then
  echo "Error: Destination directory '$DESTINATION' does not exist"
  exit 1
fi

BACKUP_NAME=$(basename "$SOURCE")

if [ "$TIMESTAMP" = true ]; then
  TIMESTAMP_STR=$(date +%Y%m%d_%H%M%S)
  BACKUP_NAME="${BACKUP_NAME}_${TIMESTAMP_STR}"
fi

if [ "$COMPRESS" = true ]; then
  BACKUP_FILE="${DESTINATION}/${BACKUP_NAME}.tar.gz"
  [ "$VERBOSE" = true ] && echo "Creating compressed backup: $BACKUP_FILE"
  tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"
  echo "Backup created: $BACKUP_FILE"
else
  BACKUP_PATH="${DESTINATION}/${BACKUP_NAME}"
  [ "$VERBOSE" = true ] && echo "Copying to: $BACKUP_PATH"
  cp -r "$SOURCE" "$BACKUP_PATH"
  echo "Backup created: $BACKUP_PATH"
fi
