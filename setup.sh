###----------------------------------------###
###  EDIT OPTIONS BELOW
###----------------------------------------###

# Comment these if you don't want defaults for
# each installation.
update_system="y"
use_memcached="y"

###----------------------------------------###
###  Do some simple checks first
###----------------------------------------###
all_clean="y"

function ok() {
  echo 'OK' | sed $'s/OK/\e[1;32m&\e[0m/'
}

function fail() {
  echo 'FAILED' | sed $'s/FAILED/\e[1;31m&\e[0m/'
  echo ""
  echo "Please fix the failed issue and run this script again."
  echo ""
  exit 1
}

function confirm() {
  echo -n " - $1"
  test $2 && ok || fail
}

function is_installed() {
  echo -n " - $1: "
  test $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") \
    -eq 0 && will_install || skip_install
}

function will_install() {
  echo 'NOT INSTALLED'
}

function skip_install() {
  all_clean="n"
  echo 'INSTALLED' | sed $'s/INSTALLED/\e[1;32m&\e[0m/'
}

echo ""
echo "In order to ensure things work as expected, we need to run some checks
first:"
echo ""

confirm "Is Ubuntu-based system: " "-e /etc/lsb-release"
confirm "Run as root: " "$EUID -eq 0"

echo ""
echo "Now, this script will look for installed packages so it won't overwrite
any existing configurations:"
echo ""

is_installed "mysql-server"
is_installed "nginx"
is_installed "php7.1-fpm"
is_installed "ssmtp"

echo ""
if [ "$all_clean" = "y" ]; then
  echo "Congrats, seems like a new server, proceeding to setup..."
else
  echo "Seems like you may have some (or all) packages already installed,
because of the way packages are configured to work together, this script does
not encourage installing over a partially configured server and will now exit.
Try running this script again on a freshly provisioned server instead."
  echo ""
  exit 1
fi

###----------------------------------------###
### DO NOT EDIT OPTIONS BELOW
###----------------------------------------###
SCRIPT_PATH=$( cd $(dirname $0) ; pwd -P )
readonly SCRIPT_PATH

TOTAL_MEMORY=$(free -m | awk '/^Mem:/{print $2}')M
readonly TOTAL_MEMORY

HAS_SWAP=$(free -m | awk '/^Swap:/{print $2}')
readonly HAS_SWAP

if [ -z "$update_system" ]; then
  read -p "Upgrade system/packages? [y/N] " update_system
fi

if [ -z "$use_memcached" ]; then
  read -p "Install memcached? [y/N] " use_memcached
fi

# This shouldn't be set with a default.
if [ "$HAS_SWAP" -eq 0 ]; then
  read -p "Setup swap (size: $TOTAL_MEMORY)? [y/N] " use_swap
fi

echo "Configuring sSMTP for root account:"
read -p "GMail address: " ssmtp_email
read -s -p "GMail password (use app password if 2FA is enabled): " ssmtp_pass

###----------------------------------------###
###  Update and upgrade the OS
###----------------------------------------###
echo ""
echo "You can go for a coffee break now, no more input needed hereon till the
end of setup."
read -p "Press [Enter] to continue"

echo "Updating and upgrading the OS..."

apt-get install -y language-pack-en-base
LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php --yes

apt-get update
apt-get install python-software-properties expect git curl --quiet --assume-yes

if [ "$update_system" = "y" ] ; then
  apt-get upgrade --quiet --assume-yes
fi

###----------------------------------------###
### Configure swapfile
###----------------------------------------###
if [ "$use_swap" = "y" ]; then
  echo "Configuring swapfile for use..."
  fallocate -l $TOTAL_MEMORY /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile    none    swap    sw    0    0" | tee -a /etc/fstab
fi

###----------------------------------------###
###  Install & Configure OpenSSH-Server
###----------------------------------------###
apt-get install openssh-server --quiet --assume-yes
sed --in-place=.old \
  --expression='s/^PermitRootLogin yes/PermitRootLogin without-password/g' \
  --expression='s,/usr/lib/openssh/sftp-server,internal-sftp,g' \
  /etc/ssh/sshd_config

echo "Adding sftponly match stanza to sshd_config..."
tee -a /etc/ssh/sshd_config < $SCRIPT_PATH/config/openssh/sftp.txt
addgroup sftponly

/etc/init.d/ssh restart

###----------------------------------------###
###  Install & Configure sSMTP
###----------------------------------------###
# For sending email
# - Will remove exim4 and its dependencies.
apt-get install ssmtp --quiet --assume-yes

mv /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.old
cp $SCRIPT_PATH/config/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf

sed -i "s/USERNAME/$ssmtp_email/g" /etc/ssmtp/ssmtp.conf
sed -i "s/PASSWORD/$ssmtp_pass/g" /etc/ssmtp/ssmtp.conf

# Add root to mail group first.
chown root:mail /etc/ssmtp/ssmtp.conf
chmod 640 /etc/ssmtp/ssmtp.conf

/usr/sbin/ssmtp $ssmtp_email < $SCRIPT_PATH/motd.txt

###----------------------------------------###
###  Install apticron
###----------------------------------------###
apt-get install apticron --quiet --assume-yes
sed --in-place=.old \
  --expression='s/^EMAIL="root"/EMAIL="'$ssmtp_email'"/g' \
  /etc/apticron/apticron.conf

###----------------------------------------###
### Install &  Configure PHP7/-FPM
###----------------------------------------###
apt-get install \
  php7.1-common \
  php7.1-mysql \
  php7.1-curl \
  php7.1-gd \
  php7.1-cli \
  php7.1-fpm \
  php7.1-dev \
  php7.1-mcrypt \
  php7.1-json \
  php7.1-opcache \
  php7.1-mbstring \
  php7.1-zip \
  php7.1-tidy \
  php7.1-recode \
  --quiet --assume-yes

echo "Importing PHP-FPM config..."
mv /etc/php/7.1/fpm/php-fpm.conf /etc/php/7.1/fpm/php-fpm.conf.old
cp $SCRIPT_PATH/config/php/php-fpm.conf /etc/php/7.1/fpm/php-fpm.conf

sed --in-place=.old \
  's,^;sendmail_path =,sendmail_path = /usr/sbin/ssmtp -t,g' \
  /etc/php/7.1/fpm/php.ini

# Remove default user pool, php-fpm won't
# start without a user pool so it will only
# startup when we add a first user.
rm /etc/php/7.1/fpm/pool.d/www.conf
/etc/init.d/php7.1-fpm stop

###----------------------------------------###
###  Configure Nginx
###----------------------------------------###
apt-get install nginx --quiet --assume-yes

#remove default config
rm /etc/nginx/sites-enabled/default

echo "Importing nginx config..."
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
cp $SCRIPT_PATH/config/nginx/nginx.conf /etc/nginx/nginx.conf

echo "Backing up and removing restrictions.conf if it exists..."
mv /etc/nginx/conf.d/restrictions.conf /etc/nginx/conf.d/restrictions.conf.old
cp $SCRIPT_PATH/config/nginx/restrictions.conf /etc/nginx/conf.d/restrictions.conf
cp $SCRIPT_PATH/config/nginx/caches.conf /etc/nginx/conf.d/caches.conf

#Restart service
/etc/init.d/nginx restart

###----------------------------------------###
###  Install Memcached
###----------------------------------------###
if [ "$use_memcached" = "y" ]; then
  apt-get install memcached --quiet --assume-yes
fi

###----------------------------------------###
###  Install & Configure MySQL
###----------------------------------------###
DEBIAN_FRONTEND=noninteractive apt-get install mysql-server --quiet --assume-yes

cp $SCRIPT_PATH/config/mysql/custom.cnf /etc/mysql/conf.d/custom.cnf

# Set MySQL root password
cd ~
MYSQL_ROOT_PASSWORD=$(perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..pop' 36)
mysqladmin -u root password $MYSQL_ROOT_PASSWORD
expect -c "
spawn mysql_config_editor set --login-path=root --host=localhost --user=root --password
expect -nocase \"Enter password:\" {send \"$MYSQL_ROOT_PASSWORD\r\"; interact}
"
cd -

/etc/init.d/mysql restart

echo "+------------------------------------+"
echo "| MySQL Username: root"
echo "| MySQL Password: $MYSQL_ROOT_PASSWORD"
echo "+------------------------------------+"

echo "Congratulations, the setup is completed. If the e-mail setup was successful, you
should receive a test e-mail sent to the e-mail address you provided."
echo "You may now invoke ./add_user.sh to add new users! Have fun!"

cd ~
