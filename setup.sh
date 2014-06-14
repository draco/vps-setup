###----------------------------------------###
###  EDIT OPTIONS BELOW
###----------------------------------------###

update_system="n"
use_dotdeb="y"
use_sstmp="y"

###----------------------------------------###
### DO NOT EDIT OPTIONS BELOW
###----------------------------------------###

SCRIPT_PATH=$( cd $(dirname $0) ; pwd -P )

if [ -z "$use_dotdeb" ]; then
  read -p "Use DotDeb? (yN) " use_dotdeb
fi

if [ -z "$update_system" ]; then
  read -p "Update system? (yN) " update_system
fi

if [ -z "$use_sstmp" ]; then
  read -p "Use sSMTP? (yN) " use_sstmp
fi

if [ "$use_sstmp" = "y" ] ; then
  echo "Configuring sSMTP:"
  read -p "GMail address: " ssmtp_email
  read -s -p "GMail password: " ssmtp_pass
fi

echo "Starting install..."

###----------------------------------------###
###  Update and upgrade the OS
###----------------------------------------###
sudo apt-get update

# Install any general & required packages
sudo apt-get \
  install \
  expect \
  git \
  curl \
  aptitude \
  python-software-properties \
  --quiet --assume-yes

if [ "$use_dotdeb" = "y" ] ; then
  ### Add DotDeb repository from http://www.dotdeb.org/instructions/
  sudo cp $SCRIPT_PATH/config/sources/dotdeb.list /etc/apt/sources.list.d/dotdeb.list
  wget --quiet --output-document=- http://www.dotdeb.org/dotdeb.gpg | sudo apt-key add -
fi

sudo aptitude update

if [ "$update_system" = "y" ] ; then
  sudo aptitude upgrade --quiet --assume-yes
fi

###----------------------------------------###
###  Install Services
###----------------------------------------###

#openssh server
sudo aptitude install openssh-server

#nginx
sudo aptitude install nginx --quiet --assume-yes

#mysql
sudo DEBIAN_FRONTEND=noninteractive aptitude install mysql-server --quiet --assume-yes

#php
sudo aptitude install php5-common php5-mysql php5-curl php5-gd php5-cli php5-fpm php5-dev php5-mcrypt --quiet --assume-yes

###----------------------------------------###
###  Configure MySQL
###----------------------------------------###
sudo aptitude install \
  php5-common \
  php5-mysql \
  php5-curl \
  php5-gd \
  php5-cli \
  php5-fpm \
  php5-dev \
  php5-mcrypt \
  --quiet --assume-yes

sudo cp $SCRIPT_PATH/config/mysql/custom.cnf /etc/mysql/conf.d/custom.cnf

# Set MySQL root password
cd ~
MYSQL_ROOT_PASSWORD=$(perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..pop' 36)
mysqladmin -u root password $MYSQL_ROOT_PASSWORD
expect -c "
spawn mysql_config_editor set --login-path=root --host=localhost --user=root --password
expect -nocase \"Enter password:\" {send \"$MYSQL_ROOT_PASSWORD\r\"; interact}
"
cd -

sudo /etc/init.d/mysql restart

###----------------------------------------###
###  Configure Nginx
###----------------------------------------###

#remove default config
sudo rm /etc/nginx/sites-enabled/default

echo "Importing nginx config"
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
sudo cp $SCRIPT_PATH/config/nginx/nginx.conf /etc/nginx/nginx.conf

echo "Backing up and removing restrictions.conf if it already exists"
sudo mv /etc/nginx/conf.d/restrictions.conf /etc/nginx/conf.d/restrictions.conf.old
sudo rm /etc/nginx/conf.d/restrictions.conf
sudo cp $SCRIPT_PATH/config/nginx/restrictions.conf /etc/nginx/conf.d/restrictions.conf
sudo cp $SCRIPT_PATH/config/nginx/caches.conf /etc/nginx/conf.d/caches.conf

#Restart service
sudo /etc/init.d/nginx restart

###----------------------------------------###
###  Configure PHP-FPM
###----------------------------------------###

echo "Importing PHP-FPM config"
sudo mv /etc/php5/fpm/php-fpm.conf /etc/php5/fpm/php-fpm.conf.old
sudo rm /etc/php5/fpm/php-fpm.conf
sudo cp $SCRIPT_PATH/config/php/php-fpm.conf /etc/php5/fpm/php-fpm.conf

#remove default www pool
sudo rm /etc/php5/fpm/pool.d/www.conf

#Output details for admin
echo "Root MySQL Password: "
echo ${MYSQL_ROOT_PASSWORD}

###----------------------------------------###
### Clean up and restart services
###----------------------------------------###
cd ~
