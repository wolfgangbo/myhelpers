#!/usr/bin/env fish

# Rename multiple files with a given pattern

function show_help
    echo "Usage: "(basename (status -f))" [OPTIONS] PATTERN REPLACEMENT [DIRECTORY]"
    echo ""
    echo "Rename multiple files with a given pattern."
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help          Show this help message"
    echo "    -r, --recursive     Recursively rename files in subdirectories"
    echo "    -d, --dry-run       Show what would be renamed without renaming"
    echo "    -v, --verbose       Verbose output"
    echo "    -e, --extension EXT Only rename files with specified extension"
    echo ""
    echo "EXAMPLES:"
    echo "    "(basename (status -f))" old new ./files"
    echo "    "(basename (status -f))" -e txt draft final ."
    echo "    "(basename (status -f))" -r test_ '' /path/to/files"
end

set -l recursive no
set -l dry_run no
set -l verbose no
set -l extension ""
set -l pattern ""
set -l replacement ""
set -l directory "."

argparse h/help r/recursive d/dry-run v/verbose 'e/extension=' -- $argv
or return 1

if set -q _flag_help
    show_help
    return 0
end

set -q _flag_recursive; and set recursive yes
set -q _flag_dry_run; and set dry_run yes
set -q _flag_verbose; and set verbose yes
set -q _flag_extension; and set extension $_flag_extension

if test (count $argv) -lt 2
    echo "Error: PATTERN and REPLACEMENT are required"
    show_help
    return 1
end

set pattern $argv[1]
set replacement $argv[2]
test (count $argv) -ge 3; and set directory $argv[3]

if not test -d $directory
    echo "Error: Directory '$directory' does not exist"
    return 1
end

set -l count 0
set -l find_cmd find $directory

if test $recursive = no
    set find_cmd $find_cmd -maxdepth 1
end

set find_cmd $find_cmd -type f

if test -n "$extension"
    set find_cmd $find_cmd -name "*.$extension"
end

eval $find_cmd | while read -l filepath
    set -l filename (basename $filepath)
    set -l dirname (dirname $filepath)

    if string match -q "*$pattern*" $filename
        set -l newname (string replace -a $pattern $replacement $filename)

        if test "$filename" != "$newname"
            if test $dry_run = yes
                echo "[DRY RUN] Would rename: $filepath -> $dirname/$newname"
            else
                mv $filepath $dirname/$newname
                test $verbose = yes; and echo "Renamed: $filename -> $newname"
            end
            set count (math $count + 1)
        end
    end
end

echo "Renamed $count file(s)"
