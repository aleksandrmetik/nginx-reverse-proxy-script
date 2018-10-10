#!/bin/bash
#
# Start example: create-reverse-proxy.sh test.com both with-www 192.168.1.84:8080
#
# Argument 1 = full domain name, example: test.com
# Argument 2 = what kind of type we should create?
#	https - only https with certbot
#	http - only http
#	both - http and https
#	https-redirect - http with redirect to https
# Argument 3 = Should we create www subdomain or no?
#       with-www - we'll create two configs, for main domain and www.
#	without-www - we'll create config only for main domain
# Argument 4 = target IP/DNS and HTTP port
#
# Variables:
# NGINX_SITES_AVAILABLE: Where is nginx folder with available domain?
# NGINX_SITES_ENABLE: Where is nginx folder with enabled domains?
# WEB_ROOT: Where is WEBROOT folder
# WEB_ROOT_HTML: Where is WEBROOT/html folder
# SED: Where is SED bin
# DOMAIN: Setup by Argument 1
# DOMAINCHECK: Regexp pattern to check domain name as valid
# DOMAIN_UNDERSCORE: Rewrited all dots in DOMAIN as underscore. Used in some cases as  web_root dir, log name and etc
# NGINX_CONFIG: Path to Nginx config file for this DOMAIN
# TEMPLATE_DIR: Path to index template dir

TEMPLATE_DIR=
NGINX_SITES_AVAILABLE='/etc/nginx/sites-available'
NGINX_SITES_ENABLED='/etc/nginx/sites-enabled'
DOMAIN_UNDERSCORE=`echo $DOMAIN | $SED 's/\./_/g'`
WEB_ROOT='/var/www/$DOMAIN_UNDERSCORE'
WEB_ROOT_HTML='/var/www/$DOMAIN_UNDERSCORE/html'
SED=`which sed`

# Check: if all argument has been filed?
if [ "$#" -ne 3 ]; then
    echo "You must enter exactly 3 command line arguments"
fi

# Check: if domain has been filed. Is domain  correct?
if [ -z $1 ]; then
	echo "No domain name"
	exit 1
fi

DOMAIN=$1

DOMAINCHECK="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"

if [[ "$DOMAIN" =~ $DOMAINCHECK ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
	echo "Creating reverse proxy for:" $DOMAIN
else
	echo "Incorrect domain name"
	exit 1
fi

# Replace dots with underscores for create directory, logs and etc


# Create nginx's config file for this domain

NGINX_CONFIG=$NGINX_SITES_AVAILABLE/$DOMAIN.conf

##################################################
#### RESERVED BLOCK (CREATE NGINX CONFIG FILE) ###
##################################################

# Create web root dir
sudo mkdir $WEB_ROOT
sudo mkdir $WEB_ROOT_HTML
sudo chown nginx:nginx -R $WEB_ROOT
sudo chmod 600 $NGINX_CONFIG

# Enable site
sudo ln -s $NGINX_CONFIG $NGINX_SITES_ENABLED/$DOMAIN.conf

##################################################
#### RESERVED BLOCK (TEST NGINX CONFIG FILE) 
### I will use array function:
### text=
### text+=
###              OR
### read -r -d '' text <<-"EOT"
###        Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
###        tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, 
###        quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea ...
### EOT
###
### echo "$text"      # only outputs index [0], the first line
### echo "${text[*]}" # output complete text (joined by first character of IFS)
###
##################################################

read -r -d '' SITE_CONFIG <<-"EOT"
server {
        listen 80;
        listen [::]:80;

        root $WEB_ROOT_HTML;
        index index.html index.htm;
	access_log  /var/log/nginx/$DOMAIN_UNDERSCORE\_access.log;
	error_log  /var/log/nginx/$DOMAIN_UNDERSCORE\_error.log;"
        server_name $DOMAIN;

        location / {
                try_files $uri $uri/ =404;
        }
#	proxy_pass  http://;
	proxy_set_header   Host             \$host;
	proxy_set_header   X-Real-IP        \$remote_addr;
	proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
	client_max_body_size       32m;
        client_body_buffer_size    1m;
        proxy_connect_timeout      600; # timeout for connection to backend
        proxy_send_timeout         600; # timeout between write-requests of a single connection
        proxy_read_timeout         600;


}
EOT

# Reload Nginx to load new config
sudo /etc/init.d/nginx reload

# Put the index.html file to web dir
sudo cp $TEMPLATE_DIR/index.html.template $WEB_ROOT_HTML/index.html
sudo chown nginx:nginx $WEB_ROOT_HTML/index.html
 
echo "Reverse proxy has been created for $DOMAIN"





