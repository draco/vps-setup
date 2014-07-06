###----------------------------------------###
###  Functions
###----------------------------------------###

SCRIPT_PATH=$( cd $(dirname $0) ; pwd -P )
readonly SCRIPT_PATH

#Generates a random string of a given length -> $ randstr 16
function randstr {
    echo $(perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..pop' $1)
}

###----------------------------------------###
###  Do some simple checks first
###----------------------------------------###
if [ ! -e /etc/debian_version ]; then
  echo "ERROR: Run this script on Debian-based systems only."
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as the root user only."
  exit 1
fi

###----------------------------------------###
###  Prompt User
###----------------------------------------###
echo "Hello, beginning setup now."
echo "Some questions first..."

read -p "Username to setup: " username
read -p "Domain for this site: " domain
read -p "Allow use of sSMTP?: [y/N] " allow_smtp
read -p "Restrict user to sFTP (no ssh)?: [y/N] " sftp_only

if [ "$sftponly" != 'y']; then
  read -p "Add user to sudo?: [y/N] " add_sudo
fi

###----------------------------------------###
###  Confirm Inputs
###----------------------------------------###
echo "You have entered:"
echo "Username: $username"
echo "Domain: $domain"
echo "Use sSMTP: $allow_smtp"
echo "Restrict to sFTP: $sftp_only"

if [ "$sftponly" != 'y']; then
  echo "Add user to sudo: $add_sudo"
fi

read -p "Are you 100% sure this is correct?: [y/N] " confirmgo

if [ "$confirmgo" != "y" ] ; then
    echo "Better try again!"
    exit 1
fi
echo "Ok, here we go!"

###----------------------------------------###
###  Create User account
###----------------------------------------###
password=$(randstr 36)
sudo useradd --create-home \
  --password=$(perl -e 'print crypt($ARGV[0], "password")' $password) \
  --shell=/bin/bash \
  $username
echo "Created new username with username \"$username\""

#Create www folder and log folders
sudo su - $username -c "cd ~ && mkdir www;
mkdir -p logs/nginx;
"

###----------------------------------------###
### sFTP configuration
###----------------------------------------###
if [ "$sftp_only" = "y" ]; then
  echo "Setting up $username sFTP chroot..."

  # Assumes home directory is /home, not sure how to generate
  # it dynamically and reliably.
  sudo chown $username:sftponly --recursive /home/$username/www/
  sudo chown root:root /home/$username/
  sudo chmod 755 /home/$username

  echo "Denying $username shell access..."
  sudo usermod --shell=/bin/false \
    --home=/home/$username/ \
    $username

  echo "Adding $username to sftponly group..."
  sudo usermod --append --groups sftponly $username
fi

###----------------------------------------###
### Add user to sudo
###----------------------------------------###
if [ "$add_sudo" = 'y' ]; then
  echo "Adding user to sudo group..."
  sudo usermod --append --groups sudo $username
fi

###----------------------------------------###
### Allow to use sSMTP
###----------------------------------------###
if [ "$allow_smtp" = "y" ]; then
  echo "Adding $username to mail group..."
  sudo usermod --append --groups mail $username
fi

###----------------------------------------###
###  Create MySQL User
###----------------------------------------###
db_user="${username:0:16}" #limit to first 16 characters - this will need to strip out special characters that are allowed in usernames like "-"
db_pass=$(randstr 36)

mysql --login-path=root --execute="CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
mysql --login-path=root --execute="FLUSH PRIVILEGES;"

###----------------------------------------###
###  Create MySQL Database
###----------------------------------------###
mysql --login-path=root --execute="CREATE DATABASE $db_user;GRANT ALL PRIVILEGES ON $db_user.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
mysql --login-path=root --execute="FLUSH PRIVILEGES;"

###----------------------------------------###
###  Setup PHP Pool
###----------------------------------------###

sudo cp $SCRIPT_PATH/config/php/user-pool.conf /etc/php5/fpm/pool.d/$username.conf
sudo sed -i "s/USERNAME/$username/g" /etc/php5/fpm/pool.d/$username.conf

sudo /etc/init.d/php5-fpm restart

###----------------------------------------###
###  Configure NGINX Host
###----------------------------------------###

# Create virtual host
sudo su - $username -c "cd ~/www && mkdir -p $domain/public_html;
echo 'It works!' > $domain/public_html/index.html"

sudo cp $SCRIPT_PATH/config/nginx/user.conf /etc/nginx/sites-available/$username-$domain.conf
sudo sed -i "s/USERNAME/$username/g" /etc/nginx/sites-available/$username-$domain.conf
sudo sed -i "s/DOMAIN/$domain/g" /etc/nginx/sites-available/$username-$domain.conf

# Create local nginx.conf as the user
sudo su - $username -c "touch ~/www/nginx.conf"

# Enable site
sudo ln -s /etc/nginx/sites-available/$username-$domain.conf /etc/nginx/sites-enabled/$username-$domain.conf

sudo /etc/init.d/nginx restart

###----------------------------------------###
###  Output details for admin
###----------------------------------------###
echo "+------------------------------------+"
echo "| Account Username: $username"
echo "| Account Password: $password"
echo "+------------------------------------+"
echo "| MySQL Username: $db_user"
echo "| MySQL Password: $db_pass"
echo "+------------------------------------+"
