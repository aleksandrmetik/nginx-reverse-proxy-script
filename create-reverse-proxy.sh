#!/bin/bash
#
# Start example: create-reverse-proxy.sh test.com both with-www http://192.168.1.84:8080
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
# Argument 4 = target IP/DNS. Example: http://192.168.1.10:8080 
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
# 

TEMPLATE_DIR=
NGINX_SITES_AVAILABLE='/etc/nginx/sites-available'
NGINX_SITES_ENABLED='/etc/nginx/sites-enabled'
DOMAIN=$1
MODE_PROTOCOL=$2
MODE_WWW=$3
PROXY_TARGET=$4

SED=$(which sed)
DOMAINCHECK="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
NGINX_CONFIG=$NGINX_SITES_AVAILABLE/$DOMAIN.conf
DOMAIN_UNDERSCORE=$(echo $DOMAIN | $SED 's/\./_/g') # Replace dots with underscores for create directory, logs and etc
WEB_ROOT="/var/www/$DOMAIN_UNDERSCORE"
WEB_ROOT_HTML="/var/www/$DOMAIN_UNDERSCORE/html"

# Check: if all argument has been filed?
if [ "$#" -ne 4 ]; then
    echo "You must enter exactly 4 command line arguments"
fi

# Check: if domain has been filed. Is domain  correct?
if [ -z $1 ]; then
	echo "No domain name"
	exit 1
fi


if [[ "$DOMAIN" =~ $DOMAINCHECK ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
	echo "Creating reverse proxy for:" $DOMAIN
else
	echo "Incorrect domain name"
	exit 1
fi

# Checks: if mode protocol has been filed

if [[ $MODE_PROTOCOL =~ ^(https|http|both|https-redirect)$ ]];
  then
   echo "Mode = $MODE_PROTOCOL is correct"
  else 
   echo "Incorrect mode protocol"
   exit 1
fi

# Check: if subdomain mode has been filed

if [[ $MODE_WWW =~ ^(with-www|without-www)$ ]];
  then
   echo "Mode WWW = $MODE_WWW is correct"
  else
   echo "Incorrect mode of WWW"
   exit 1
fi




##################################################
####        (CREATE NGINX CONFIG FILE)         ###
##################################################

function createnginxconfig {
# Create nginx's config file for this domain
### TEST BLOCK
echo "#################################"
echo "#################################"
echo "DOMAIN = $DOMAIN"
echo "MODE_PROTOCOL = $MODE_PROTOCOL"
echo "MODE_WWW = $MODE_WWW"
echo "PROXY_TARGET = $PROXY_TARGET"
echo "NGINX_CONFIG = $NGINX_CONFIG"
echo "SED = $SED"
echo "DOMAIN_UNDERSCORE = ${DOMAIN_UNDERSCORE}"
echo "WEB_ROOT = $WEB_ROOT"
echo "#################################"
echo "#################################"



	cat <<EOT > $NGINX_CONFIG


	server {
	        listen 80;
	        server_name ${DOMAIN};

	        root ${WEB_ROOT_HTML};
	        index index.html index.htm;
		access_log  /var/log/nginx/${DOMAIN_UNDERSCORE}_access.log;
		error_log  /var/log/nginx/${DOMAIN_UNDERSCORE}_error.log;

		location = /robots.txt {
			add_header Content-Type text/plain;
	       		return 200 "User-agent: *\nDisallow: /\n";
		}

	        location / {
			proxy_pass  http://${PROXY_TARGET};
			proxy_set_header   Host             \$host;
			proxy_set_header   X-Real-IP        \$remote_addr;
			proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
			proxy_set_header   X-Forwarded-Proto \$scheme;
			client_max_body_size       1000m;
	        	client_body_buffer_size    1m;
	        	proxy_connect_timeout      600; # timeout for connection to backend
	        	proxy_send_timeout         600; # timeout between write-requests of a single connection
	        	proxy_read_timeout         600;
	 		}
	}
EOT

	cat $NGINX_CONFIG 

	# Create web root dir
	sudo mkdir $WEB_ROOT 
	sudo mkdir $WEB_ROOT_HTML 
	sudo chown www-data:www-data -R $WEB_ROOT
	sudo chmod 600 $NGINX_CONFIG

	# Enable site
	sudo ln -s $NGINX_CONFIG $NGINX_SITES_ENABLED/$DOMAIN.conf

	##################################################
	#           (TEST NGINX CONFIG FILE) 
	nginx -t || (echo "Config test has been failed, changes has been reverted" && sudo rm $NGINX_SITES_ENABLED/$DOMAIN.conf && exit 1) 
	nginx -t && service nginx reload
	#################################################

	# Work with HTTP & HTTP

	if [[ $MODE_PROTOCOL = "https-redirect" ]];
	  then
	   echo "Implement HTTPS with redirect.."
	   certbot  --nginx -n --redirect -d $DOMAIN
	fi

	if [[ $MODE_PROTOCOL = "https" ]];
	  then
	   echo "Implement ONLY HTTPS"
	   certbot  --nginx -n --no-redirect -d $DOMAIN
	   sed -i '/listen 80;/d' $NGINX_CONFIG
	fi

	if [[ $MODE_PROTOCOL = "both" ]];
	  then
	   echo "Implement ONLY HTTPS"
	   certbot  --nginx -n --no-redirect -d $DOMAIN
	fi

	if [[ $MODE_PROTOCOL = "http" ]];
	  then
	   echo "ONLY HTTP, certbot has been skipped"
	fi

##################################################
#           (TEST NGINX CONFIG FILE) 
nginx -t || (echo "Config test has been failed, changes has been reverted" && sudo rm $NGINX_SITES_ENABLED/$DOMAIN.conf)
nginx -t && service nginx reload

##################################################
# Reload Nginx to load new config
sudo /etc/init.d/nginx reload

# Put the index.html file to web dir
sudo cp $TEMPLATE_DIR/index.html.template $WEB_ROOT_HTML/index.html
sudo chown www-data:www-data $WEB_ROOT_HTML/index.html

echo "Reverse proxy has been created for $DOMAIN"
}

# Work with subdomain

if [[ $MODE_WWW = without-www ]];
  then
   echo "Mode WWW = $MODE_WWW is correct"
   echo "Create reverse proxy without subdomain"
   createnginxconfig;
fi

if [[ $MODE_WWW = with-www ]];
  then
   echo "Mode WWW = $MODE_WWW is correct"
   echo "Create reverse proxy for main domain = $DOMAIN..."
   createnginxconfig
   # Preparing for www. subdomain
   NGINX_CONFIG=$NGINX_SITES_AVAILABLE/${DOMAIN}_www.conf
   DOMAIN_UNDERSCORE=$(echo $DOMAIN | $SED 's/\./_/g') # Replace dots with underscores for create directory, logs and etc
   WEB_ROOT="/var/www/${DOMAIN_UNDERSCORE}_www"
   WEB_ROOT_HTML="/var/www/${DOMAIN_UNDERSCORE}_www/html"
   DOMAIN=www.$DOMAIN
   echo "Create reverse proxy for main WWW subdomain = $DOMAIN..."
   createnginxconfig
fi
