# Argument 1 = full domain name, example: test.com
# Argument 2 = 
#
# Variables:
# NGINX_SITES_AVAILABLE: Where is nginx folder with available domain?
# NGINX_SITES_ENABLE: Where is nginx folder with enabled domains?
# WEB_ROOT: Where is WEBROOT folder
# SED: Where is SED bin
# DOMAIN: Setup by Argument 1
# DOMAINCHECK: Regexp pattern to check domain name as valid
# DOMAIN_UNDERSCORE: Rewrited all dots in DOMAIN as underscore. Used in some cases as  web_root dir, log name and etc
# NGINX_CONFIG: Path to Nginx config file for this DOMAIN



NGINX_SITES_AVAILABLE='/etc/nginx/sites-available'
NGINX_SITES_ENABLED='/etc/nginx/sites-enabled'
WEB_ROOT='/var/www'
SED=`which sed`

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

DOMAIN_UNDERSCORE=`echo $DOMAIN | $SED 's/\./_/g'`

# Create nginx's config file for this domain
NGINX_CONFIG=$NGINX_SITES_AVAILABLE/$DOMAIN.conf

##################################################
#### RESERVED BLOCK (CREATE NGINX CONFIG FILE) ###
##################################################

# Create web root dir
sudo mkdir $WEB_ROOT/$DOMAIN_UNDERSCORE
sudo chown nginx:nginx -R $WEB_ROOT/$DOMAIN_UNDERSCORE
sudo chmod 600 $NGINX_CONFIG

# Enable site
sudo ln -s $NGINX_CONFIG $NGINX_SITES_ENABLED/$DOMAIN.conf

##################################################
#### RESERVED BLOCK (TEST NGINX CONFIG FILE) ###
##################################################

# Reload Nginx to load new config
sudo /etc/init.d/nginx reload

# Put the index.html file to web dir
sudo cp $TEMPLATE_DIR/index.html.template $WEB_ROOT/$DOMAIN_UNDERSCORE/index.html
sudo chown nginx:nginx $WEB_ROOT/$DOMAIN_UNDERSCORE/index.html
 
echo "Reverse proxy has been created for $DOMAIN"





