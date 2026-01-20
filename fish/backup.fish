#!/usr/bin/env fish

# Backup files and directories to a specified location

function show_help
    echo "Usage: "(basename (status -f))" [OPTIONS] SOURCE DESTINATION"
    echo ""
    echo "Backup files and directories to a specified location."
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help          Show this help message"
    echo "    -c, --compress      Compress backup using tar.gz"
    echo "    -t, --timestamp     Add timestamp to backup name"
    echo "    -v, --verbose       Verbose output"
    echo ""
    echo "EXAMPLES:"
    echo "    "(basename (status -f))" /home/user/documents /backup/location"
    echo "    "(basename (status -f))" -ct /etc /backup/config"
end

set -l compress no
set -l timestamp no
set -l verbose no
set -l source ""
set -l destination ""

argparse 'h/help' 'c/compress' 't/timestamp' 'v/verbose' -- $argv
or return 1

if set -q _flag_help
    show_help
    return 0
end

set -q _flag_compress; and set compress yes
set -q _flag_timestamp; and set timestamp yes
set -q _flag_verbose; and set verbose yes

if test (count $argv) -lt 2
    echo "Error: SOURCE and DESTINATION are required"
    show_help
    return 1
end

set source $argv[1]
set destination $argv[2]

if not test -e $source
    echo "Error: Source '$source' does not exist"
    return 1
end

if not test -d $destination
    echo "Error: Destination directory '$destination' does not exist"
    return 1
end

set backup_name (basename $source)

if test $timestamp = yes
    set timestamp_str (date +%Y%m%d_%H%M%S)
    set backup_name "$backup_name"_"$timestamp_str"
end

if test $compress = yes
    set backup_file "$destination/$backup_name.tar.gz"
    test $verbose = yes; and echo "Creating compressed backup: $backup_file"
    tar -czf $backup_file -C (dirname $source) (basename $source)
    echo "Backup created: $backup_file"
else
    set backup_path "$destination/$backup_name"
    test $verbose = yes; and echo "Copying to: $backup_path"
    cp -r $source $backup_path
    echo "Backup created: $backup_path"
end
