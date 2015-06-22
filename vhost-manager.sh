#!/bin/bash

# A VirtualHost manager for Apache 2.2 tested on CentOS 6.6

# derived from https://github.com/unnikked/Apache-VirtualHost-Manager

function show_help() {
	cat << EOF
Usage: ${0##*/} -a ACTION -w DOMAIN_NAME [-e EMAIL] [-n VHOST_NAME] [-r DIR_NAME] [-d] [-u] [-v] [-h]
	
	-a		create, delete, enable, disable or list
	-w		domain name (eg example.com)
	-e		webmaster email
	-n		name of the virtual host (if not specified it uses
			DOMAIN_NAME)
	-r		name of the virtual host directory under ${apache_www}
			(if not specified it uses VHOST_NAME)
	-d		delete the virtual host directory
	-u		set owner of the virtual host directory
	-v		verbose
	-h		this help		
EOF
}

username=$(logname)

aFlag=false
action=""
email=""
wFlag=false
domainname=""
domainnames=""
vhostname=""
vhost_dirname=""
vhost_subdir_web="/web"
vhost_subdir_log="/log"
log_dirname=""
dFlag=false
vFlag=false
verbose=0

OPTIND=1

sites_enabled="/etc/httpd/conf/sites-enabled/"
sites_available="/etc/httpd/conf/sites-available/"
apache_www="/var/www-vhosts/"

while getopts "a:e:w:n:d:vh" opt; do
	case "$opt" in
		v)	verbose=$((verbose+1))
			vFlag=true
			;;
		e)	email=$OPTARG
			;;
		a)	action=$OPTARG
			aFlag=true
			;;
		w)	domainname=$OPTARG
			wFlag=true
			;;
		n)	vhostname=$OPTARG
			;;
		r)	vhost_dirname=$OPTARG
			;;
		d)	dFlag=true
			;;
		u)	username=$OPTARG
			;;
		h) 	show_help
			exit 0
			;;
		'?')
#			show_help >&2
			exit 1
			;;
	esac
done

shift "$((OPTIND-1))" # Shift off the options and optional --.

if ! $aFlag; then # -a is mandatory
	echo "You must specify an action"
	show_help
	exit 1
fi

if [ "$(id -u)" != 0 ]; then
	echo "You must be root or use sudo"
	exit 1
fi

if ! which httpd > /dev/null; then
	echo -e "You must install apache webserver first\n	sudo yum install httpd"
	exit 1
fi

if [ $action == "list" ]; then
	echo "Enabled VirtualHosts:"
	for v in $(ls $sites_enabled); do echo ${v%%".conf"}; done
	echo
	echo "Disabled VirtualHosts:"
	comm -23 <(for v in $(ls $sites_available); do echo ${v%%".conf"}; done | sort) <(for v in $(ls $sites_enabled); do echo ${v%%".conf"}; done | sort)
	exit 0
fi

if ! $wFlag; then # -w is mandatory
	echo "You must atleast provide a domain name"
	exit 1
fi

# if no -n is provided then it will be set the same as domainname
if [ -z "$vhostname" ]; then 
	vhostname="$domainname"
fi

# if no -d is provided then it will be set the same as vhostname
if [ -z "$vhost_dirname" ]; then
	vhost_dirname="$vhostname"
fi

# if no -e is provided then it will be set to webmaster@domainname
if [ -z "$email" ]; then
	email="webmaster@$domainname"
fi

# set the log directory name
if [ -z "$log_dirname" ]; then
	log_dirname="${apache_www}${vhost_dirname}${vhost_subdir_log}"
fi

# set server alias
if [ -z "$domainnames" ]; then
	domainnames="$domainname www.$domainname"
fi

vHostTemplate="$(echo "<Directory ${apache_www}${vhost_dirname}>
	AllowOverride None
	Order deny,allow
	Deny from all
</Directory>

<VirtualHost *:80>
	DocumentRoot ${apache_www}${vhost_dirname}${vhost_subdir_web}
	ServerName $domainname
	ServerAlias $domainnames
	ServerAdmin $email 
	ErrorLog ${log_dirname}/error.log
	CustomLog ${log_dirname}/access.log common

	<Directory ${apache_www}${vhost_dirname}${vhost_subdir_web}>
		Options Indexes FollowSymLinks
		AllowOverride all
		Order allow,deny
		Allow from all
	</Directory>

	# Possible values include: debug, info, notice, warn, error, crit,
	# alert, emerg.
	#LogLevel warn
</VirtualHost>")"

function verbose() {
	if $vFlag; then
		echo "$1"
	fi
	return 0
}


if [ "$action" == "create" -o "$action" == "enable" ]; then
	if [ "$action" == "create" ]; then
		# checks if domain already exists
		if [ -e "${sites_available}${vhostname}.conf" ]; then
			echo -e "This domain already exists."
			exit 1;
		fi
	
		# checks if the folder already exists
		if [ -d "${apache_www}${vhost_dirname}" ]; then
			echo "Directory already exists!"
			exit 1;
		fi
	
		# creates the folder
		if ! mkdir -p "${apache_www}${vhost_dirname}" > /dev/null; then
			echo "An error occurred while creating "${apache_www}${vhost_dirname}""
			exit 1
		else
			if ! [ -z "$vhost_subdir_web" ]; then
				mkdir -p "${apache_www}${vhost_dirname}${vhost_subdir_web}" > /dev/null
			fi
			if ! [ -z "$vhost_subdir_log" ]; then
				mkdir -p "${apache_www}${vhost_dirname}${vhost_subdir_log}" > /dev/null
			fi
			echo "Folder "${apache_www}${vhost_dirname}" created"

			echo "<?php phpinfo();?>" > ${apache_www}${vhost_dirname}${vhost_subdir_web}/index.php
		fi
	
		# sets www-data permission
		if chown -R $username:$username ${apache_www}${vhost_dirname} > /dev/null; then
			verbose "Folder permission changed"
		else 
			echo "An error occurred while changing permission to "$vhost_dirname""
			exit 1
		fi
		if ! [ -z "$vhost_subdir_log" ]; then
			if chown -R apache:apache ${apache_www}${vhost_dirname}${vhost_subdir_log} > /dev/null; then
				verbose "Log folder permission changed"
			else 
				echo "An error occurred while changing permission to "${vhost_dirname}${vhost_subdir_log}""
				exit 1
			fi
		fi
	
		# creates VirtualHost file
		if echo "$vHostTemplate" > ${sites_available}${vhostname}.conf; then
			verbose "VirtualHost created"
		else
			echo "An error occurred! Could not write to ${sites_available}${vhostname}"
			exit 1
		fi
	fi

	# enables virtual host
	if ! [ -e "${sites_enabled}${vhostname}.conf" ]; then
		if [ -e "${sites_available}${vhostname}.conf" ]; then
			if ln -s ${sites_available}${vhostname}.conf ${sites_enabled}${vhostname}.conf > /dev/null; then
				verbose "Site "$domainname" enabled."
			else
				echo "An error occurred while enabling "$domainname""
				exit 1
			fi
		else
			echo "Domain "$domainname" doest not exist."
			exit 1
		fi
	else
		if [ "$action" == "enable" ]; then
			echo "Domain "$domainname" is already enabled."
			exit 1
		fi
	fi
	
	if [ "$action" == "create" ]; then
		# Insert domainnames into /etc/hosts
		if ! [ -z "$domainnames" ]; then
			sed -i "/^127.0.0.1	$domainnames\$/d" /etc/hosts
			echo "127.0.0.1	$domainnames" >> /etc/hosts
		fi
	fi

	# reloads apache config
	if service httpd reload > /dev/null; then 
		verbose "Apache config reloaded"
	else
		echo "An error occurred while reloading apache"
		exit 1
	fi

	exit 0
fi

if [ "$action" == "delete" -o "$action" == "disable" ]; then
	if [ "$action" == "delete" ]; then
		# checks if the domain does not exists
		if ! [ -e "${sites_enabled}${vhostname}.conf" ]; then
			echo -e "This domain does not exists."
			exit 1;
		fi
	
		# checks if the folder does not exists
		if ! [ -d "${apache_www}${vhost_dirname}" ]; then
			echo "Directory does not exists!"
			exit 1;
		fi
	fi
	
	# disable virtual host
	if [ -e "${sites_enabled}${vhostname}.conf" ]; then
		if unlink ${sites_enabled}${vhostname}.conf > /dev/null; then
			verbose "Domain "$domainname" disabled"
		else
			echo "An error occurred while disabling "$domainname""
			exit 1
		fi
	else
		if [ "$action" == "disable" ]; then
			if [ -e "${sites_available}${vhostname}.conf" ]; then
				echo "Domain "$domainname" is already disabled"
			else
				echo "Domain "$domainname" does not exists!"
			fi
			exit 1
		fi
	fi
	
	if [ "$action" == "delete" ]; then
		# Remove domainnames from /etc/hosts
		if ! [ -z "$domainnames" ]; then
			sed -i "/^127.0.0.1	$domainnames\$/d" /etc/hosts
		fi
	
		# deletes virtual host file
		if [ -e "${sites_available}${vhostname}.conf" ]; then
			if rm ${sites_available}${vhostname}.conf > /dev/null; then
				verbose "VirtualHost "$vhostname" deleted."
			else
				echo "An error occurred while deleting directory "$vhost_dirname""
				exit 1
			fi
		fi
	
		# deletes the directory
		if $dFlag; then
			if rm -rf ${apache_www}${vhost_dirname} > /dev/null; then
				verbose "Directory "$vhost_dirname" deleted."
			else
				echo "An error occurred while deleting directory "$vhost_dirname""
				exit 1
			fi
		fi
	fi

	# reloads apache config
	if service httpd reload > /dev/null; then 
		verbose "Apache config reloaded"
	else
		echo "An error occurred while reloading apache"
		exit 1
	fi

	exit 0
fi

echo "Unknow action!"
exit 1
