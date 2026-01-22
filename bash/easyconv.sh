#!/bin/bash

#############################################################################
# Encoding Converter Script - WSL Optimized
# Converts files from various encodings to UTF-8
#############################################################################

set -uo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="./encoding_backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="./encoding_conversion_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false
VERBOSE=false
CREATE_BACKUP=true
ADD_BOM=false  # By default, create UTF-8 without BOM

# Default excluded directories
EXCLUDE_DIRS=(
    "node_modules"
    "packages"
    "bin"
    "obj"
    ".git"
    ".idea"
    ".vs"
    ".vscode"
    "bower_components"
    "wwwroot/lib"
    "Scripts"
)

# File extensions
FILE_EXTENSIONS=(
    "*.cs"
    "*.cshtml"
    "*.aspx"
    "*.ascx"
    "*.master"
    "*.asax"
    "*.config"
    "*.xml"
    "*.js"
    "*.css"
    "*.html"
    "*.htm"
    "*.txt"
    "*.sql"
    "*.json"
    "*.resx"
    "*.vb"
)

# Statistics
TOTAL_FILES=0
CONVERTED_FILES=0
SKIPPED_FILES=0
FAILED_FILES=0

#############################################################################
# Functions
#############################################################################

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Convert files from various encodings to UTF-8.

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Perform a dry run
    -v, --verbose           Verbose output
    -n, --no-backup         Don't create backup
    -b, --bom               Add UTF-8 BOM (Byte Order Mark)
    --no-bom                Ensure no BOM (default)
    -e, --extensions EXT    File extensions (comma-separated)
    -x, --exclude DIRS      Exclude directories (comma-separated)
    -l, --log FILE          Log file path

ABOUT BOM (Byte Order Mark):
    UTF-8 BOM is a 3-byte sequence (EF BB BF) at the start of files.
    
    Use --bom for:
      - Legacy .NET Framework projects that expect BOM
      - Windows applications that require BOM
      - ASP.NET Web Forms (.aspx, .ascx)
    
    Use --no-bom (default) for:
      - Modern .NET (Core/5+) projects
      - Linux/cross-platform applications
      - Most web files (HTML, CSS, JS)
      - JSON, XML files

EXAMPLES:
    $0 /mnt/c/project                    # Convert to UTF-8 without BOM
    $0 --bom /mnt/c/project              # Convert to UTF-8 with BOM
    $0 -d -v /mnt/c/project              # Dry run, verbose
    $0 -x "packages,lib" /mnt/c/project  # Exclude directories

EOF
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

check_deps() {
    for cmd in file iconv; do
        if ! command -v "$cmd" &> /dev/null; then
            printf "%s Error: '$cmd' not found. Install with: sudo apt install file libc-bin${NC}\n" "${RED}" >&2
            exit 1
        fi
    done
}

is_utf8() {
    local file=$1
    local enc
    enc=$(file -b --mime-encoding "$file" 2>/dev/null || echo "unknown")
    [[ "$enc" =~ ^(utf-8|us-ascii)$ ]]
}

has_bom() {
    local file=$1
    # Check if file starts with UTF-8 BOM (EF BB BF)
    local first_bytes
    first_bytes=$(head -c 3 "$file" 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "$first_bytes" = "efbbbf" ]
}

add_bom() {
    local file=$1
    # UTF-8 BOM is: EF BB BF
    printf '\xEF\xBB\xBF' > "${file}.bom"
    cat "$file" >> "${file}.bom"
    mv "${file}.bom" "$file"
}

remove_bom() {
    local file=$1
    # Remove first 3 bytes if they are BOM
    if has_bom "$file"; then
        tail -c +4 "$file" > "${file}.nobom"
        mv "${file}.nobom" "$file"
    fi
}

convert_file() {
    local file=$1
    local base
        base=$(basename "$file")
    # local already_utf8=false
    local had_bom=false
    
    # Check if already UTF-8
    if is_utf8 "$file"; then
        # already_utf8=true
        had_bom=$(has_bom "$file" && echo true || echo false)
        
        # If already UTF-8, we might still need to adjust BOM
        if [ "$ADD_BOM" = true ] && [ "$had_bom" = false ]; then
            # Need to add BOM
            if [ "$DRY_RUN" = true ]; then
                printf "  ${BLUE}BOM+${NC} %s (add BOM)\n" "$base"
                log "BOM+: $file (would add BOM)"
                ((CONVERTED_FILES++))
                return 0
            fi
            add_bom "$file"
            printf "  ${GREEN}BOM+${NC} %s (added BOM)\n" "$base"
            log "BOM+: $file (added BOM)"
            ((CONVERTED_FILES++))
            return 0
        elif [ "$ADD_BOM" = false ] && [ "$had_bom" = true ]; then
            # Need to remove BOM
            if [ "$DRY_RUN" = true ]; then
                printf "  ${BLUE}BOM-${NC} %s (remove BOM)\n" "$base"
                log "BOM-: $file (would remove BOM)"
                ((CONVERTED_FILES++))
                return 0
            fi
            remove_bom "$file"
            printf "  ${GREEN}BOM-${NC} %s (removed BOM)\n" "$base"
            log "BOM-: $file (removed BOM)"
            ((CONVERTED_FILES++))
            return 0
        else
            # Already correct
            [ "$VERBOSE" = true ] && printf "  ${YELLOW}SKIP${NC} %s (already UTF-8%s)\n" "$base" "$([ "$had_bom" = true ] && echo " with BOM" || echo "")"
            log "SKIP: $file (already UTF-8, BOM=$had_bom)"
            ((SKIPPED_FILES++))
            return 0
        fi
    fi
    
    local from_enc
        from_enc=$(file -b --mime-encoding "$file" 2>/dev/null || echo "unknown")
    
    if [ "$DRY_RUN" = true ]; then
        printf "  ${BLUE}DRY${NC}  %s (%s -> UTF-8%s)\n" "$base" "$from_enc" "$([ "$ADD_BOM" = true ] && echo " with BOM" || echo "")"
        log "DRY: $file ($from_enc -> UTF-8, BOM=$ADD_BOM)"
        ((CONVERTED_FILES++))
        return 0
    fi
    
    # Create backup
    if [ "$CREATE_BACKUP" = true ]; then
        local rel_path="${file#./}"
        local backup="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup")"
        cp "$file" "$backup" 2>/dev/null || {
            printf "  ${RED}FAIL${NC} %s (backup failed)\n" "$base"
            log "FAIL: $file (backup failed)"
            ((FAILED_FILES++))
            return 1
        }
    fi
    
    # Try conversion
    local tmp="${file}.utf8tmp"
    local success=false
    
    # Try detected encoding first
    if [ "$from_enc" != "unknown" ] && [ "$from_enc" != "binary" ]; then
        if iconv -f "$from_enc" -t UTF-8 "$file" > "$tmp" 2>/dev/null; then
            success=true
        fi
    fi
    
    # Try common encodings if detection failed
    if [ "$success" = false ]; then
        for enc in ISO-8859-1 WINDOWS-1252 CP1252 LATIN1; do
            if iconv -f "$enc" -t UTF-8 "$file" > "$tmp" 2>/dev/null; then
                from_enc=$enc
                success=true
                break
            fi
        done
    fi
    
    if [ "$success" = true ]; then
        # Handle BOM
        if [ "$ADD_BOM" = true ]; then
            # Add BOM to converted file
            printf '\xEF\xBB\xBF' > "${tmp}.bom"
            cat "$tmp" >> "${tmp}.bom"
            mv "${tmp}.bom" "$tmp"
        fi
        
        mv "$tmp" "$file"
        printf "  ${GREEN}CONV${NC} %s (%s -> UTF-8%s)\n" "$base" "$from_enc" "$([ "$ADD_BOM" = true ] && echo " +BOM" || echo "")"
        log "CONV: $file ($from_enc -> UTF-8, BOM=$ADD_BOM)"
        ((CONVERTED_FILES++))
    else
        rm -f "$tmp"
        printf "  ${RED}FAIL${NC} %s (conversion failed)\n" "$base"
        log "FAIL: $file (conversion failed)"
        ((FAILED_FILES++))
        return 1
    fi
}

process_dir() {
    local dir=$1
    
    printf "Scanning directory: %s\n" "$dir"
    log "Scanning: $dir"
    
    # Build find command
    local find_args=("$dir")
    
    # Add exclusions
    for excl in "${EXCLUDE_DIRS[@]}"; do
        [ -n "$excl" ] && find_args+=(-path "*/$excl" -prune -o -path "*/$excl/*" -prune -o)
    done
    
    # Add file type filter
    find_args+=(-type f \()
    for i in "${!FILE_EXTENSIONS[@]}"; do
        [ "$i" -gt 0 ] && find_args+=(-o)
        find_args+=(-name "${FILE_EXTENSIONS[$i]}")
    done
    find_args+=(\) -print)
    
    # Get file list
    printf "Finding files...\n"
    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(find "${find_args[@]}" 2>/dev/null)
    
    local count=${#files[@]}
    printf "Found %d files\n\n" "$count"
    
    if [ "$count" -eq 0 ]; then
        printf "No files to process!\n"
        return
    fi
    
    # Process files
    local current=0
    for file in "${files[@]}"; do
        ((current++))
        ((TOTAL_FILES++))
        
        printf "[%3d%%] %4d/%d: " $((current * 100 / count)) "$current" "$count"
        convert_file "$file"
    done
    
    printf "\nProcessing complete!\n\n"
}

print_summary() {
    printf "\n"
    printf "==========================================\n"
    printf "           CONVERSION SUMMARY\n"
    printf "==========================================\n"
    printf "Total files:          %d\n" "$TOTAL_FILES"
    printf "${GREEN}Converted:${NC}            %d\n" "$CONVERTED_FILES"
    printf "${YELLOW}Already UTF-8:${NC}        %d\n" "$SKIPPED_FILES"
    printf "${RED}Failed:${NC}               %d\n" "$FAILED_FILES"
    printf "==========================================\n"
    
    if [ "$CREATE_BACKUP" = true ] && [ "$DRY_RUN" = false ] && [ $CONVERTED_FILES -gt 0 ]; then
        printf "Backup: %s\n" "$BACKUP_DIR"
    fi
    
    printf "Log: %s\n\n" "$LOG_FILE"
}

#############################################################################
# Main
#############################################################################

main() {
    local target_dir="."
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--no-backup)
                CREATE_BACKUP=false
                shift
                ;;
            -b|--bom)
                ADD_BOM=true
                shift
                ;;
            --no-bom)
                ADD_BOM=false
                shift
                ;;
            -e|--extensions)
                IFS=',' read -ra FILE_EXTENSIONS <<< "$2"
                for i in "${!FILE_EXTENSIONS[@]}"; do
                    FILE_EXTENSIONS[i]="*.${FILE_EXTENSIONS[i]#*.}"
                done
                shift 2
                ;;
            -x|--exclude)
                if [ -z "$2" ]; then
                    EXCLUDE_DIRS=()
                else
                    IFS=',' read -ra add_excl <<< "$2"
                    EXCLUDE_DIRS+=("${add_excl[@]}")
                fi
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -*)
                printf "Unknown option: %s\n" "$1" >&2
                print_usage
                exit 1
                ;;
            *)
                target_dir="$1"
                shift
                ;;
        esac
    done
    
    # Validate
    if [ ! -d "$target_dir" ]; then
        printf "${RED}Error: Directory not found: %s${NC}\n" "$target_dir" >&2
        exit 1
    fi
    
    check_deps
    
    # Print config
    printf "==========================================\n"
    printf "  Encoding Conversion for .NET Migration\n"
    printf "==========================================\n"
    printf "Target: %s\n" "$target_dir"
    printf "Dry run: %s\n" "$DRY_RUN"
    printf "Backup: %s\n" "$CREATE_BACKUP"
    printf "UTF-8 BOM: %s\n" "$([ "$ADD_BOM" = true ] && echo "Yes (add BOM)" || echo "No (remove BOM)")"
    printf "Verbose: %s\n" "$VERBOSE"
    printf "Extensions: %s\n" "${FILE_EXTENSIONS[*]}"
    if [ ${#EXCLUDE_DIRS[@]} -gt 0 ]; then
        printf "Excluded: %s\n" "${EXCLUDE_DIRS[*]}"
    fi
    printf "Log: %s\n" "$LOG_FILE"
    printf "==========================================\n\n"
    
    # Create log
    touch "$LOG_FILE"
    log "START: Encoding conversion"
    
    # Process
    process_dir "$target_dir"
    
    # Summary
    print_summary
    
    [ $FAILED_FILES -gt 0 ] && exit 1
    exit 0
}

main "$@"


