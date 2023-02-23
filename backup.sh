#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Global variables
# -----------------------------------------------------------------------------

APPNAME="${0%.*}" && APPNAME="${APPNAME##*/}"

# -----------------------------------------------------------------------------
# Log functions
# -----------------------------------------------------------------------------

logInfo()  { 
	echo "$(date +'%Y-%m-%d %H:%M:%S') $APPNAME: [INFO] $1" >> ./log/script.log; 
}
logWarn()  { 
	echo "$(date +'%Y-%m-%d %H:%M:%S') $APPNAME: [WARNING] $1" >> ./log/script.log; 
}
logError() {
	echo "$(date +'%Y-%m-%d %H:%M:%S') $APPNAME: [ERROR] $1" >> ./log/script.log; 
}

# -----------------------------------------------------------------------------
# Print functions
# -----------------------------------------------------------------------------

success(){
	echo -e "\033[0;32m$1\033[0m"
}

error(){
	echo -e "\033[0;31m$1\033[0m"
}

debug(){
	echo -e "\033[0;34m$1\033[0m"
}

logo(){
	echo -e '\033[0;31m                        )      (      (       ) (               *     \033[0m'
	echo -e '\033[0;31m   (    (       (    ( /(      )\ )   )\ ) ( /( )\ ) *   )    (  `    \033[0m'
	echo -e '\033[0;31m ( )\   )\      )\   )\())  ( (()/(  (()/( )\()(()/` )  /((   )\))(   \033[0m'
	echo -e '\033[0;31m )((_((((_)(  (((_)|((_)\   )\ /(_))  /(_)((_)\ /(_)( )(_))\ ((_)()\  \033[0m'
	echo -e '\033[0;31m((_)_ )\ _ )\ )\___|_ ((__ ((_(_))   (_))__ ((_(_))(_(_()((_)(_()((_) \033[0m'
	echo -e '\033[0;31m | _ )(_)_\(_((/ __| |/ | | | | _ \  / __\ \ / / __|_   _| __|  \/  | \033[0m'
	echo -e "\033[0;31m | _ \ / _ \  | (__  ' <| |_| |  _/  \__ \\ V /\__ \ | | | _|| |\/| | \033[0m"
	echo -e '\033[0;31m |___//_/ \_\  \___|_|\_\\___/|_|    |___/ |_| |___/ |_| |___|_|  |_| \033[0m'
}

# -----------------------------------------------------------------------------
# Small utility functions for reducing code duplication
# -----------------------------------------------------------------------------

displayUsage() {
	logo
	echo ""
	echo ""
	echo "$(basename $0) is a tool to perform backups in a network context"
	echo "Usage: $(basename $0) [OPTION]..."
	echo ""
	echo "General options"
	echo " -h, --help             Display this help message."
	echo ""
	echo "Options to manipulate the server list"
	echo " -a, --add              Add destination host. (Ex. $(basename $0) -a user@80.23.32.14)"
	echo " -r, --remove           Remove destination host. (Ex. $(basename $0) -r user@80.23.32.14)"
	echo " -l, --list             Print the list of all hosts entered."
	echo ""
	echo "Options to setup a CronJob"
	echo " -L, --listcron         Print the list of currents crontab."
	echo " -s, --setcron          Add a new CronJob for a sever."
	echo " -e, --removecron       remove a server from the CronJob."
	echo ""
	echo "Options to make a backup"
	echo " -m, --manual           Backup single server in list."
	echo " -A, --all              Backup all server in list"

	echo ""
	echo "For more detailed help, please see the README file:"
	echo ""
	echo ""
}

# -----------------------------------------------------------------------------
# Notification functions
# -----------------------------------------------------------------------------

sendInfo()  { 
	GROUP_ID="-1001596128784"
	BOT_TOKEN="5675870116:AAFlfuIQuqL0aw3nStwI5CcvXFqATbku6LU"
	curl -s --data "text=$1" --data "chat_id=$GROUP_ID" 'https://api.telegram.org/bot'$BOT_TOKEN'/sendMessage' > /dev/null
}

# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------

checkInstall(){
	PACKAGES=(sshpass curl tar gzip gpg crontab)
	for package in "${PACKAGES[@]}"; do
		if ! command -v "$package" > /dev/null 2>&1; then
			debug "$package is not installed. Start of installation..."
		if [ "$(uname -s)" == "Linux" ]; then
			sudo apt-get update
			sudo apt-get install "$package"
		elif [ "$(uname -s)" == "Darwin" ]; then
			brew install "$package"
		else
			error "Operating system not supported. Install $package manualy"
			exit 1
		fi
		success "Installation $package completed"
		fi
	done
}

checkDir(){
	files_to_check=("./log/script.log" "backup" "database.csv")
	for file in "${files_to_check[@]}"
	do
		if [ ! -e "$file" ]
		then
			error "File: $file does not exist!"
			exit 1
		fi
	done
}

check_password() {
    sshpass -p "$1" ssh -o ConnectTimeout=5 -o "StrictHostKeyChecking=no" -q $2@$3 exit
    return $?
}

init(){
	checkInstall
	checkDir
}

# -----------------------------------------------------------------------------
# CSV file management
# -----------------------------------------------------------------------------

addHost() {
	local regex="^[^@]+@([0-9]{1,3}\.){3}[0-9]{1,3}(:[0-9]+)?$"
	local usr ip port password

	if echo "$1" | grep -q -E "$regex"; then
		# Extract username and IP address
		usr=$(echo "$1" | cut -d '@' -f 1)
		ip=$(echo "$1" | cut -d '@' -f 2 | cut -d ':' -f 1)

		# Check if port is specified
		if echo "$1" | grep -q ':'; then
			# Extract specified port
			port=$(echo "$1" | cut -d ':' -f 2)
		else
			# Port not specified, set to default 22
			port=22
		fi

		#Check if the server already exist in database
		if grep -q "$ip" "database.csv"; then
			error "The line already exists in the file"
			exit 1
		fi

		# Ask add a password
		while true; do
			read -s -p "Please enter password: " password
			echo
			if check_password "$password" "$usr" "$ip"; then
				success "Successful connection, I add the server."
				break
			else
				error "Incorrect password. Please try again."
			fi
		done

		echo "$usr,$ip,$port,$password" >> database.csv
		success "Server added successfully"
		logInfo "successful addition for Username: $usr, IP: $ip, Porta: $port, Pwd: $password"
	else
		error "The string is in the wrong format. Please try again or check instructions."
		logWarn "The string is in the wrong format. Please try again or check instructions."
	fi
}

rmHost() {
	local regex="^[^@]+@([0-9]{1,3}\.){3}[0-9]{1,3}?$"

	if echo "$1" | grep -q -E "$regex"; then
		# Extract username and IP address
		local usr=$(echo "$1" | cut -d '@' -f 1)
		local ip=$(echo "$1" | cut -d '@' -f 2 | cut -d ':' -f 1)

		# look for the line corresponding to the user and IP address in the CSV file
		if grep -q "$usr,$ip" database.csv; then
			# delete the line from the file
			sed -i "/$usr,$ip/d" database.csv
			success "Line corresponding to $usr@$ip deleted from file."
			logInfo "Line corresponding to $usr@$ip deleted from file."
		else
			error "No line found matching $usr@$ip."
			logWarn "No line found matching $usr@$ip."
		fi
	else
		error "The string is in the wrong format. Please try again or check instructions."
		logWarn "The string is in the wrong format. Please try again or check instructions."
	fi
}

lsHost() {
	if [ -s database.csv ]
	then
		while IFS=',' read -r username ip porta pwd
			do
				debug "IP: ${ip}:${porta} Username: ${username}"
		done < database.csv
	else
		error "No server found in database"
	fi
}

# -----------------------------------------------------------------------------
# Backup function
# -----------------------------------------------------------------------------

manualSingleBackup() {
  # Read lines from CSV file and save them in an array
  readarray -t hosts < database.csv

  # Create a clickable menu with CSV file lines
  PS3="Select a row: "
  select host in "${hosts[@]}"; do
    # If the user has selected a row continue
    if [[ -n "$host" ]]; then
		IFS=',' read -ra data <<< "$host"
		# check if ssh conection pass with nc
		debug "Start of backup for server ${data[1]}"
		debug "Checking the response from the server..."		
		if nc -z -w 5 "${data[1]}" 22; then
			# Ask the user to enter a directory
			while true; do
				read -p "Enter the path to the backup directory: " dirbackup
				# Check if the directory exists
				if [[ "$dirbackup" =~ ^/([^/]+/?)*$ ]]; then
					break
				else
					error "The $dirbackup directory does not exist or the path is incorrect. Please try again."
				fi
			done
			sshpass -p "${data[3]}" rsync --progress -avz -e 'ssh -o "StrictHostKeyChecking=no"' ${data[0]}@${data[1]}:$dirbackup /home/backupmaster/BackupSystem/backup/"$APPNAME-${data[0]}@${data[1]}"
			success "Rsync completed successfully"
			logInfo "Rsync completed successfully for ${data[0]}@${data[1]} check ./backup/"$APPNAME-${data[0]}@${data[1]}""
			sendInfo "Rsync completed successfully for ${data[0]}@${data[1]} check ./backup/"$APPNAME-${data[0]}@${data[1]}""
		else
			# SSH conection fail
			error "SSH is not running on ${data[1]}"
			logError "SSH is not running on ${data[1]}"
		fi
      	break
    fi
  done
}

makeAllBakcupSever() {
	readarray -t hosts < database.csv
    for host in "${hosts[@]}"; do 
        IFS=',' read -ra data <<< "$host"
        # Check if SSH connection passes with nc
		debug "Start of backup for server ${data[1]}"
		debug "Checking the response from the server..."
        if nc -z -w 5 "${data[1]}" 22; then
			# Ask the user to enter a directory
			while true; do
				read -p "Enter the path to the backup directory: " dirbackup
				# Check if the directory exists
				if [[ "$dirbackup" =~ ^/([^/]+/?)*$ ]]; then
					break
				else
					error "The $dirbackup directory does not exist or the path is incorrect. Please try again."
				fi
			done
			sshpass -p "${data[3]}" rsync --progress -avz -e 'ssh -o "StrictHostKeyChecking=no"' ${data[0]}@${data[1]}:$dirbackup /home/backupmaster/BackupSystem/backup/"$APPNAME-${data[0]}@${data[1]}"
			success "Rsync completed successfully"
			logInfo "Rsync completed successfully for ${data[0]}@${data[1]} check ./backup/"$APPNAME-${data[0]}@${data[1]}""
			sendInfo "Rsync completed successfully for ${data[0]}@${data[1]} check ./backup/"$APPNAME-${data[0]}@${data[1]}""
        else
            # SSH connection fails
            error "SSH is not running on ${data[1]}"
            logError "SSH is not running on ${data[1]}"
        fi
    done
}

# -----------------------------------------------------------------------------
# CronJob functions
# -----------------------------------------------------------------------------

setCronJob(){
  # Read lines from CSV file and save them in an array
  readarray -t hosts < database.csv

    # Get the current user's name
    local user=$(whoami)

    # Get the current crontab for the user
    local current_crontab=$(crontab -u "$user" -l)

  # Create a clickable menu with CSV file lines
  PS3="Select a row: "
  select host in "${hosts[@]}"; do
    # If the user has selected a row continue
    if [[ -n "$host" ]]; then
		IFS=',' read -ra data <<< "$host"
		# check if ssh conection pass with nc 
		debug "Checking the response from the server..."
		if nc -z -w 5 "${data[1]}" 22; then
			#Ask a patch to backup
			while true; do
				read -p "Enter the path to the backup directory: " dirbackup
				# Check if the directory exists
				if [[ "$dirbackup" =~ ^/([^/]+/?)*$ ]]; then
					break
				else
					error "The $dirbackup directory does not exist or the path is incorrect. Please try again."
				fi
			done
			#Ask a frequency crontab
			while true; do
				read -p "Enter the crontab execution frequency format (e.g. 0 3 * * *): " frequency
				if [[ "$frequency" =~ ^([0-9*]+ ){4}[0-9*]+$ ]]; then
					break
				else
					error "The format of the crontab frequency is incorrect. Please try again or check the instructions."
				fi
			done
            local job="$frequency sshpass -p '${data[3]}' rsync --progress -avz -e ssh -o \"StrictHostKeyChecking=no\" ${data[0]}@${data[1]}:$dirbackup /home/backupmaster/BackupSystem/backup/'$APPNAME-${data[0]}@${data[1]}'"
			current_crontab+="\n$job"
            echo -e "$current_crontab" | crontab -u "$user" -
            success "Added cron job for ${data[1]}"
            logInfo "Added cron job for ${data[1]}"
		else
			# SSH conection fail
			error "SSH is not running on ${data[1]}"
			logError "SSH is not running on ${data[1]}"
		fi
      	break
    fi
  done
}

removeCronJob(){
    # Get the current user's name
    local user=$(whoami)

    # Get the current crontab for the user
    local current_crontab=$(crontab -u "$user" -l)
	
	#Count a crontab
	local num_crontabs=$(echo "$current_crontab" | grep -c "^[^#]")
	
	#Check if there are crontabs
	if [ $num_crontabs -eq 0 ]; then
		error "There are no crontabs for the current user."
		exit 1
	fi
	
	# Show a crontab selection menu
	echo "Select a crontab to delete"
	echo "$current_crontab" | grep -v "^#" | nl
	while true; do
		read -p "Number of crontab: " crontab_num

		# Check if the user has entered a valid number
		if [[ "$crontab_num" =~ ^[0-9]+$ ]] && [ "$crontab_num" -ge 1 ] && [ "$crontab_num" -le $num_crontabs ]; then
			break
		else
			error "Imsert a valid number."
		fi
	done

	# Delete a select crotab
	crontab_id=$(echo "$current_crontab" | grep -v "^#" | sed -n "${crontab_num}p" | awk '{print $1}')
	crontab -l | grep -v "$crontab_id" | crontab -

	success "The selected crontab has been deleted."
}

viewCrontab(){
    # Get the current user's name
    local user=$(whoami)

    # Get the current crontab for the user
    local current_crontab=$(crontab -u "$user" -l)

	#Count a crontab
	local num_crontabs=$(echo "$current_crontab" | grep -c "^[^#]")

	#Check if there are crontabs
	if [ $num_crontabs -eq 0 ]; then
		error "There are no crontabs for the current user."
		exit 1
	fi

	# Mostra i crontab
	echo "Here are all the crontabs of the current user:"
	echo "$current_crontab" | nl
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

options=$(getopt -n backup -o ha:r:lAmseL --long help,add:,remove:,list,all,manual,setcron,removecron,listcron -- "$@")

if [ $? != "0" ] || [ $# -eq 0 ]; then
	echo -e "\n invalid use please check the instructions \n"
  	displayUsage
  	exit 1
fi

eval set -- "$options"

logInfo "script running"

while true; do
	#Checking if dependencies are installed
	init
	case $1 in
		-h|--help)
			displayUsage
			exit
			;;
		-a|--add)
			if [ "$1" = "-a" ] || [ "$1" = "--add" ] && [ -n "$2" ]; then
				# the -d option has been passed with a valid value, run rmHost
				shift
				addHost "$1"
			fi
			;;
		-r|--remove)
			if [ "$1" = "-r" ] || [ "$1" = "--remove" ] && [ -n "$2" ]; then
				# the -r option has been passed with a valid value, run rmHost
				shift
				rmHost "$1"
			fi
			;;
		-l|--list)
			lsHost
			;;
		-m|--manual)
			manualSingleBackup
			;;
		-A|--all)
			makeAllBakcupSever
			;;
		-L|--listcron)
			viewCrontab
			;;
		-s|--setcron)
			setCronJob
			;;
		-e|--removecron)
			removeCronJob
			;;
		--)
            shift
            break
            ;;
		*)
            echo "Invalid option: $1"
			logError "incorrect parameters"
            displayUsage
            exit 1
	esac
	shift || break
done
