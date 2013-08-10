###----------------------------------------###
###  EDIT OPTIONS BELOW
###----------------------------------------###

SYSTEM_UPDATE="NO"

###----------------------------------------###
###  Update and upgrade the OS
###----------------------------------------###
sudo apt-get update

# Install any general & required packages
sudo apt-get install git curl python-software-properties --force-yes --quiet --yes

if [ "$SYSTEM_UPDATE" = "YES" ] ; then
  sudo apt-get upgrade --force-yes --quiet --yes
fi

###----------------------------------------###
###  Add required PPA repositories
###----------------------------------------###

# Add MariaDB PPA
sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
sudo add-apt-repository 'deb http://ftp.osuosl.org/pub/mariadb/repo/5.5/ubuntu precise main'
sudo apt-get update

###----------------------------------------###
###  Install Services
###----------------------------------------###

#MariaDB (silence root password prompt)
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install mariadb-server --force-yes --quiet --yes

#nginx
sudo apt-get install nginx --force-yes --quiet --yes

#php
sudo apt-get install php5-common php5-mysql php5-xmlrpc php5-cgi php5-curl php5-gd php5-cli php5-fpm php-apc php5-dev php5-mcrypt --force-yes --quiet --yes

###----------------------------------------###
###  Configure MySQL
###----------------------------------------###

sudo cp config/mysql/custom.cnf /etc/mysql/conf.d/custom.cnf

# Set MySQL root password
cd ~
MYSQL_ROOT_PASSWORD=$(perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..pop' 36)
sudo service mysql stop
echo "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';" > rootpassword.sql
echo "FLUSH PRIVILEGES;" >> rootpassword.sql
sudo mysqld_safe --init-file=${HOME}/rootpassword.sql &
sudo service mysql restart
sudo rm rootpassword.sql
cd -

###----------------------------------------###
###  Configure Nginx
###----------------------------------------###

#remove default config
sudo rm /etc/nginx/sites-enabled/default

echo "Importing nginx config"
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
sudo cp config/nginx/nginx.conf /etc/nginx/nginx.conf

echo "Backing up and removing restrictions.conf if it already exists"
sudo mv /etc/nginx/conf.d/restrictions.conf /etc/nginx/conf.d/restrictions.conf.old
sudo rm /etc/nginx/conf.d/restrictions.conf
sudo cp config/nginx/restrictions.conf /etc/nginx/conf.d/restrictions.conf

#Restart service
sudo service nginx stop
sudo service nginx start

###----------------------------------------###
###  Configure PHP-FPM
###----------------------------------------###

echo "Importing PHP-FPM config"
sudo mv /etc/php5/fpm/php-fpm.conf /etc/php5/fpm/php-fpm.conf.old
sudo rm /etc/php5/fpm/php-fpm.conf
sudo cp config/php/php-fpm.conf /etc/php5/fpm/php-fpm.conf

#remove default www pool
sudo rm /etc/php5/fpm/pool.d/www.conf

#Restart service
sudo service php5-fpm stop
sudo service php5-fpm start

###----------------------------------------###
###  Install WP-CLI
###----------------------------------------###

curl http://wp-cli.org/installer.sh > installer.sh
sudo INSTALL_DIR='/usr/share/wp-cli' bash installer.sh
sudo ln -s /usr/share/wp-cli/bin/wp /usr/bin/wp

#Output details for admin
echo "Root MySQL Password: "
echo ${MYSQL_ROOT_PASSWORD}

#Later we will run new_user.sh here to create a default site. new_user.sh will need to accept arguments first