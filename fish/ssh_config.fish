#!/usr/bin/env fish

# Manage SSH configuration files

set -l SSH_CONFIG $HOME/.ssh/config
set -l SSH_DIR $HOME/.ssh

function show_help
    echo "Usage: "(basename (status -f))" [COMMAND] [OPTIONS]"
    echo ""
    echo "Manage SSH configuration files."
    echo ""
    echo "COMMANDS:"
    echo "    list                List all configured SSH hosts"
    echo "    add                 Add a new SSH host configuration"
    echo "    remove HOST         Remove an SSH host configuration"
    echo "    show HOST           Show configuration for a specific host"
    echo "    backup              Backup SSH configuration"
    echo "    restore FILE        Restore SSH configuration from backup"
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help          Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "    "(basename (status -f))" list"
    echo "    "(basename (status -f))" add"
    echo "    "(basename (status -f))" remove myserver"
    echo "    "(basename (status -f))" show myserver"
    echo "    "(basename (status -f))" backup"
end

function ensure_ssh_dir
    if not test -d $SSH_DIR
        mkdir -p $SSH_DIR
        chmod 700 $SSH_DIR
    end
end

function list_hosts
    if not test -f $SSH_CONFIG
        echo "No SSH config file found at $SSH_CONFIG"
        return
    end

    echo "Configured SSH hosts:"
    grep "^Host " $SSH_CONFIG | sed 's/Host /  - /'
end

function add_host
    ensure_ssh_dir

    read -P "Enter host alias: " host_alias
    read -P "Enter hostname/IP: " hostname
    read -P "Enter username: " username
    read -P "Enter port (default 22): " port
    test -z "$port"; and set port 22
    read -P "Enter identity file path (optional): " identity_file

    echo "" >>$SSH_CONFIG
    echo "Host $host_alias" >>$SSH_CONFIG
    echo "    HostName $hostname" >>$SSH_CONFIG
    echo "    User $username" >>$SSH_CONFIG
    echo "    Port $port" >>$SSH_CONFIG

    if test -n "$identity_file"
        echo "    IdentityFile $identity_file" >>$SSH_CONFIG
    end

    echo "SSH host '$host_alias' added successfully!"
end

function remove_host
    set -l host $argv[1]

    if test -z "$host"
        echo "Error: Host name required"
        return 1
    end

    if not test -f $SSH_CONFIG
        echo "No SSH config file found"
        return 1
    end

    sed -i "/^Host $host\$/,/^\$/d" $SSH_CONFIG
    echo "Host '$host' removed from SSH config"
end

function show_host
    set -l host $argv[1]

    if test -z "$host"
        echo "Error: Host name required"
        return 1
    end

    if not test -f $SSH_CONFIG
        echo "No SSH config file found"
        return 1
    end

    sed -n "/^Host $host\$/,/^\$/p" $SSH_CONFIG
end

function backup_config
    if not test -f $SSH_CONFIG
        echo "No SSH config file to backup"
        return 1
    end

    set -l backup_file "$SSH_CONFIG.backup."(date +%Y%m%d_%H%M%S)
    cp $SSH_CONFIG $backup_file
    echo "SSH config backed up to: $backup_file"
end

function restore_config
    set -l backup_file $argv[1]

    if test -z "$backup_file"
        echo "Error: Backup file path required"
        return 1
    end

    if not test -f $backup_file
        echo "Error: Backup file not found"
        return 1
    end

    cp $backup_file $SSH_CONFIG
    chmod 600 $SSH_CONFIG
    echo "SSH config restored from: $backup_file"
end

set -l command list
test (count $argv) -ge 1; and set command $argv[1]

switch $command
    case -h --help
        show_help
        exit 0
    case list
        list_hosts
    case add
        add_host
    case remove
        remove_host $argv[2]
    case show
        show_host $argv[2]
    case backup
        backup_config
    case restore
        restore_config $argv[2]
    case '*'
        echo "Unknown command: $command"
        show_help
        exit 1
end
