#!/bin/bash

# Manage SSH configuration files

set -e

SSH_CONFIG="$HOME/.ssh/config"
SSH_DIR="$HOME/.ssh"

show_help() {
	cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Manage SSH configuration files.

COMMANDS:
    list                List all configured SSH hosts
    add                 Add a new SSH host configuration
    remove HOST         Remove an SSH host configuration
    show HOST           Show configuration for a specific host
    backup              Backup SSH configuration
    restore FILE        Restore SSH configuration from backup

OPTIONS:
    -h, --help          Show this help message

EXAMPLES:
    $(basename "$0") list
    $(basename "$0") add
    $(basename "$0") remove myserver
    $(basename "$0") show myserver
    $(basename "$0") backup
EOF
}

ensure_ssh_dir() {
	if [ ! -d "$SSH_DIR" ]; then
		mkdir -p "$SSH_DIR"
		chmod 700 "$SSH_DIR"
	fi
}

list_hosts() {
	if [ ! -f "$SSH_CONFIG" ]; then
		echo "No SSH config file found at $SSH_CONFIG"
		return 1
	fi

	echo "Configured SSH hosts:"
	grep "^Host " "$SSH_CONFIG" | sed 's/Host /  - /'
}

add_host() {
	ensure_ssh_dir
	echo "Enter host alias: "
	read -r host_alias
	echo "Enter hostname/IP: "
	read -r hostname
	echo "Enter username: "
	read -r username
	echo "Enter port (default 22): "
	read -r port
	port=${port:-22}
	echo "Enter identity file path (optional): "
	read -r identity_file

	{
		echo ""
		echo "Host $host_alias"
		echo "    HostName $hostname"
		echo "    User $username"
		echo "    Port $port"
		echo "    IdentityFile $identity_file"
	} >>"$SSH_CONFIG"

	echo "SSH host '$host_alias' added successfully!"
}

remove_host() {
	local host="$1"

	if [ -z "$host" ]; then
		echo "Error: Host name required"
		exit 1
	fi

	if [ ! -f "$SSH_CONFIG" ]; then
		echo "No SSH config file found"
		exit 1
	fi

	sed -i "/^Host $host$/,/^$/d" "$SSH_CONFIG"
	echo "Host '$host' removed from SSH config"
}

show_host() {
	local host="$1"

	if [ -z "$host" ]; then
		echo "Error: Host name required"
		exit 1
	fi

	if [ ! -f "$SSH_CONFIG" ]; then
		echo "No SSH config file found"
		exit 1
	fi

	sed -n "/^Host $host$/,/^$/p" "$SSH_CONFIG"
}

backup_config() {
	if [ ! -f "$SSH_CONFIG" ]; then
		echo "No SSH config file to backup"
		exit 1
	fi

	local backup_file
	backup_file="$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
	cp "$SSH_CONFIG" "$backup_file"
	echo "SSH config backed up to: $backup_file"
}

restore_config() {
	local backup_file="$1"

	if [ -z "$backup_file" ]; then
		echo "Error: Backup file path required"
		exit 1
	fi

	if [ ! -f "$backup_file" ]; then
		echo "Error: Backup file not found"
		exit 1
	fi

	cp "$backup_file" "$SSH_CONFIG"
	chmod 600 "$SSH_CONFIG"
	echo "SSH config restored from: $backup_file"
}

case "${1:-list}" in
-h | --help)
	show_help
	exit 0
	;;
list)
	list_hosts
	;;
add)
	add_host
	;;
remove)
	remove_host "$2"
	;;
show)
	show_host "$2"
	;;
backup)
	backup_config
	;;
restore)
	restore_config "$2"
	;;
*)
	echo "Unknown command: $1"
	show_help
	exit 1
	;;
esac
