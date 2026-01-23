#!/usr/bin/env fish

# Clean up temporary files and directories

function show_help
    echo "Usage: "(basename (status -f))" [OPTIONS]"
    echo ""
    echo "Clean up temporary files and directories."
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help          Show this help message"
    echo "    -a, --all           Clean all temp locations (system + user)"
    echo "    -s, --system        Clean system temp directories (requires sudo)"
    echo "    -u, --user          Clean user temp directories"
    echo "    -d, --dry-run       Show what would be deleted without deleting"
    echo "    -v, --verbose       Verbose output"
    echo ""
    echo "EXAMPLES:"
    echo "    "(basename (status -f))" --user"
    echo "    "(basename (status -f))" --all --dry-run"
    echo "    "(basename (status -f))" -sv"
end

set clean_system no
set clean_user no
set dry_run no
set verbose no

argparse h/help a/all s/system u/user d/dry-run v/verbose -- $argv
or return 1

if set -q _flag_help
    show_help
    return 0
end

set -q _flag_all; and begin
    set clean_system yes
    set clean_user yes
end
set -q _flag_system; and set clean_system yes
set -q _flag_user; and set clean_user yes
set -q _flag_dry_run; and set dry_run yes
set -q _flag_verbose; and set verbose yes

if test "$clean_system" = no; and test "$clean_user" = no
    set clean_user yes
end

function cleanup_directory
    set -l dir $argv[1]
    set -l description $argv[2]

    if not test -d $dir
        test "$verbose" = yes; and echo "Skipping $description: Directory does not exist"
        return
    end

    echo "Cleaning $description: $dir"

    if test "$dry_run" = yes
        find $dir -type f -mtime +7 2>/dev/null | while read -l file
            echo "[DRY RUN] Would delete: $file"
        end
    else
        set -l count (find $dir -type f -mtime +7 2>/dev/null | wc -l)
        find $dir -type f -mtime +7 -delete 2>/dev/null
        echo "Deleted $count file(s) older than 7 days"
    end
end

if test "$clean_user" = yes
    echo "=== Cleaning user temporary files ==="
    cleanup_directory $HOME/.cache "User cache"
    cleanup_directory /tmp "Temporary directory"
    cleanup_directory $HOME/Downloads "Downloads (old files)"
end

if test "$clean_system" = yes
    echo "=== Cleaning system temporary files ==="
    if test (id -u) -ne 0
        echo "Warning: System cleanup requires sudo privileges"
        return 1
    end
    cleanup_directory /var/tmp "System temp"
    cleanup_directory /var/log "Old logs"
end

echo "Cleanup complete!"
