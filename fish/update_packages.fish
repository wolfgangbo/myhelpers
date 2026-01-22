#!/usr/bin/env fish

# Update system packages and dependencies

function show_help
    echo "Usage: "(basename (status -f))" [OPTIONS]"
    echo ""
    echo "Update system packages and dependencies."
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help          Show this help message"
    echo "    -a, --auto          Auto-confirm updates (no prompts)"
    echo "    -c, --clean         Clean package cache after update"
    echo "    -v, --verbose       Verbose output"
    echo ""
    echo "EXAMPLES:"
    echo "    "(basename (status -f))
    echo "    "(basename (status -f))" --auto --clean"
end

set -l auto_confirm no
set -l clean_cache no
set -l verbose no

argparse h/help a/auto c/clean v/verbose -- $argv
or return 1

if set -q _flag_help
    show_help
    return 0
end

set -q _flag_auto; and set auto_confirm yes
set -q _flag_clean; and set clean_cache yes
set -q _flag_verbose; and set verbose yes

function detect_package_manager
    if command -v apt-get &>/dev/null
        echo apt
    else if command -v dnf &>/dev/null
        echo dnf
    else if command -v yum &>/dev/null
        echo yum
    else if command -v pacman &>/dev/null
        echo pacman
    else if command -v zypper &>/dev/null
        echo zypper
    else
        echo unknown
    end
end

set -l pkg_manager (detect_package_manager)

if test $pkg_manager = unknown
    echo "Error: No supported package manager found"
    return 1
end

echo "Detected package manager: $pkg_manager"
echo "=================================="

switch $pkg_manager
    case apt
        echo "Updating package lists..."
        sudo apt-get update

        if test $auto_confirm = yes
            echo "Upgrading packages..."
            sudo apt-get upgrade -y
            sudo apt-get dist-upgrade -y
        else
            echo "Upgrading packages..."
            sudo apt-get upgrade
            sudo apt-get dist-upgrade
        end

        if test $clean_cache = yes
            echo "Cleaning package cache..."
            sudo apt-get autoclean
            sudo apt-get autoremove -y
        end

    case dnf
        if test $auto_confirm = yes
            sudo dnf upgrade -y
        else
            sudo dnf upgrade
        end

        if test $clean_cache = yes
            sudo dnf clean all
            sudo dnf autoremove -y
        end

    case yum
        if test $auto_confirm = yes
            sudo yum update -y
        else
            sudo yum update
        end

        if test $clean_cache = yes
            sudo yum clean all
            sudo yum autoremove -y
        end

    case pacman
        if test $auto_confirm = yes
            sudo pacman -Syu --noconfirm
        else
            sudo pacman -Syu
        end

        if test $clean_cache = yes
            sudo pacman -Sc --noconfirm
        end

    case zypper
        if test $auto_confirm = yes
            sudo zypper refresh
            sudo zypper update -y
        else
            sudo zypper refresh
            sudo zypper update
        end

        if test $clean_cache = yes
            sudo zypper clean
        end
end

echo "=================================="
echo "Package update complete!"
