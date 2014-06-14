###----------------------------------------###
###  EDIT OPTIONS BELOW
###----------------------------------------###

# Comment these if you don't want defaults for
# each installation.
update_system="n"
use_dotdeb="y"
use_sstmp="y"
use_memcached="y"

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

if [ -z "$use_memcached" ]; then
  read -p "Use Memcached? (yN) " use_memcached
fi

if [ "$use_sstmp" = "y" ] ; then
  echo "Configuring sSMTP:"
  read -p "GMail address: " ssmtp_email
  read -s -p "GMail password: " ssmtp_pass
fi

echo "Starting installation..."

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
###  Install & Configure sSMTP
###----------------------------------------###

if [ "$use_sstmp" = "y" ] ; then
  # For sending email
  # - Will remove exim4 and its dependencies.
  sudo aptitude install ssmtp --quiet --assume-yes

  sudo mv /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.old
  sudo cp $SCRIPT_PATH/config/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf

  sudo sed -i "s/USERNAME/$ssmtp_email/g" /etc/ssmtp/ssmtp.conf
  sudo sed -i "s/PASSWORD/$ssmtp_pass/g" /etc/ssmtp/ssmtp.conf

  # Add root to mail group first.
  sudo chown root:mail /etc/ssmtp/ssmtp.conf
  sudo chmod 640 /etc/ssmtp/ssmtp.conf
fi

###----------------------------------------###
### Install &  Configure PHP5/-FPM
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

echo "Importing PHP-FPM config..."
sudo mv /etc/php5/fpm/php-fpm.conf /etc/php5/fpm/php-fpm.conf.old
sudo cp $SCRIPT_PATH/config/php/php-fpm.conf /etc/php5/fpm/php-fpm.conf

#remove default www pool
sudo rm /etc/php5/fpm/pool.d/www.conf

###----------------------------------------###
###  Configure Nginx
###----------------------------------------###
sudo aptitude install nginx --quiet --assume-yes

#remove default config
sudo rm /etc/nginx/sites-enabled/default

echo "Importing nginx config..."
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
sudo cp $SCRIPT_PATH/config/nginx/nginx.conf /etc/nginx/nginx.conf

echo "Backing up and removing restrictions.conf if it exists..."
sudo mv /etc/nginx/conf.d/restrictions.conf /etc/nginx/conf.d/restrictions.conf.old
sudo cp $SCRIPT_PATH/config/nginx/restrictions.conf /etc/nginx/conf.d/restrictions.conf
sudo cp $SCRIPT_PATH/config/nginx/caches.conf /etc/nginx/conf.d/caches.conf

#Restart service
sudo /etc/init.d/nginx restart

###----------------------------------------###
###  Install Memcached
###----------------------------------------###
if [ "$use_memcached" = "y" ]; then
  sudo aptitude install memcached
fi

###----------------------------------------###
###  Install & Configure MySQL
###----------------------------------------###
sudo DEBIAN_FRONTEND=noninteractive aptitude install mysql-server --quiet --assume-yes

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

echo "+------------------------------------+"
echo "| MySQL Username: root"
echo "| MySQL Password: $MYSQL_ROOT_PASSWORD"
echo "+------------------------------------+"

###----------------------------------------###
### Clean up and restart services
###----------------------------------------###
cd ~
