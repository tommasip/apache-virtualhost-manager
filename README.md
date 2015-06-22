# VirtualHost management script for Apache 2.2

Derived from https://github.com/unnikked/Apache-VirtualHost-Manager and adapted it to Apache 2.2 and Redhat-based system.

Tested it on CentOS 6.6

## Syntax

```
Usage: vhost-manager -a ACTION -w DOMAIN_NAME [-e EMAIL] [-n VHOST_NAME] [-r DIR_NAME] [-d] [-u] [-v] [-h]
	
	-a		create, delete, enable, disable or list
	-w		domain name (eg example.com)
	-e		webmaster email
	-n		name of the virtual host (if not specified it uses
			DOMAIN_NAME)
	-r		name of the virtual host directory under /var/www-vhosts/
			(if not specified it uses VHOST_NAME)
	-d		delete the virtual host directory
	-u		set owner of the virtual host directory
	-v		verbose
	-h		this help
```

## Example Directory Structure

The script will create virtual host files and directories with the follow structure:

```
+-- /var/www-vhosts/
  +-- example.localhost/
    +-- log/
      +-- access.log
      +-- error.log
    +-- web/
      +-- index.php
```

You have to edit the script to change the root directory (apache_www).

