#!/bin/bash

# Rename multiple files with a given pattern

set -e

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] PATTERN REPLACEMENT [DIRECTORY]

Rename multiple files with a given pattern.

OPTIONS:
    -h, --help          Show this help message
    -r, --recursive     Recursively rename files in subdirectories
    -d, --dry-run       Show what would be renamed without renaming
    -v, --verbose       Verbose output
    -e, --extension EXT Only rename files with specified extension

EXAMPLES:
    $(basename "$0") "old" "new" ./files
    $(basename "$0") -e txt "draft" "final" .
    $(basename "$0") -r "test_" "" /path/to/files
EOF
}

RECURSIVE=false
DRY_RUN=false
VERBOSE=false
EXTENSION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      show_help
      exit 0
      ;;
    -r | --recursive)
      RECURSIVE=true
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
    -e | --extension)
      EXTENSION="$2"
      shift 2
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
  echo "Error: PATTERN and REPLACEMENT are required"
  show_help
  exit 1
fi

PATTERN="$1"
REPLACEMENT="$2"
DIRECTORY="${3:-.}"

if [ ! -d "$DIRECTORY" ]; then
  echo "Error: Directory '$DIRECTORY' does not exist"
  exit 1
fi

count=0

if [ "$RECURSIVE" = true ]; then
  FIND_CMD="find \"$DIRECTORY\" -type f"
else
  FIND_CMD="find \"$DIRECTORY\" -maxdepth 1 -type f"
fi

if [ -n "$EXTENSION" ]; then
  FIND_CMD="$FIND_CMD -name \"*.$EXTENSION\""
fi

while read -r filepath; do
  filename=$(basename "$filepath")
  dirname=$(dirname "$filepath")

  if [[ "$filename" == *"$PATTERN"* ]]; then
    newname="${filename//$PATTERN/$REPLACEMENT}"
    if [ "$filename" != "$newname" ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would rename: $filepath -> $dirname/$newname"
      else
        mv "$filepath" "$dirname/$newname"
        [ "$VERBOSE" = true ] && echo "Renamed: $filename -> $newname"
      fi
      ((count += 1))
    fi
  fi
done < <(eval "$FIND_CMD")

echo "Renamed $count file(s)"
