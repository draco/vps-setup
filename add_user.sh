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
###  Prompt User
###----------------------------------------###
echo ""
echo "Adding a new user..."
echo ""
read -p "  Username: " username

if id -u $username  >/dev/null 2>&1; then
  echo ""
  echo "Sorry, the username $username is already in use. Because this script
assumes the same username for all setup, it cannot proceed."
  echo ""
  exit 1
fi

read -p "  Domain name: " domain
read -p "  Grant user access to ssmtp? [y/N] " allow_smtp
read -p "  Grant user access to ssh? [y/N] " allow_ssh

if [ "$allow_ssh" = "y" ]; then
  read -p "  Add user to sudo? [y/N] " allow_sudo
fi

###----------------------------------------###
###  Confirm Inputs
###----------------------------------------###
echo ""
echo "You have entered:"
echo ""
echo "  Username: $username"
echo "  Domain: $domain"
echo "  Allow ssmtp: $allow_smtp"
echo "  Allow ssh: $allow_ssh"

if [ "$allow_ssh" = "y" ]; then
  echo "  Add user to sudo: $allow_sudo"
fi

echo ""
read -p "  Are you 100% sure this is correct? [y/N] " confirmgo
echo ""

if [ "$confirmgo" != "y" ] ; then
    echo "Better try again!"
    exit 1
fi

echo ""
echo "Ok, here we go!"
echo ""

###----------------------------------------###
###  Create user account
###----------------------------------------###
password=$(randstr 36)
useradd --create-home \
  --password=$(perl -e 'print crypt($ARGV[0], "password")' $password) \
  --shell=/bin/bash \
  $username
echo "Created new username with username \"$username\""

#Create www folder and log folders
su - $username -c "cd ~ && mkdir www;
mkdir -p logs/nginx;
"

###----------------------------------------###
### Restrict ssh access (lock to sftp)
###----------------------------------------###
if [ "$allow_ssh" != "y" ]; then
  echo "Setting up $username sFTP chroot..."

  # Assumes home directory is /home, not sure how to generate
  # it dynamically and reliably.
  chown $username:sftponly --recursive /home/$username/www/
  chown root:root /home/$username/
  chmod 755 /home/$username
  usermod --home=/home/$username/ $username

  echo "Adding $username to sftponly group..."
  usermod --append --groups sftponly $username
fi

###----------------------------------------###
### Allow sudo access
###----------------------------------------###
if [ "$allow_sudo" = "y" ]; then
  echo "Adding user to group..."
  usermod --append --groups sudo $username
fi

###----------------------------------------###
### Allow to use sSMTP
###----------------------------------------###
if [ "$allow_smtp" = "y" ]; then
  echo "Adding $username to mail group..."
  usermod --append --groups mail $username
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
cp $SCRIPT_PATH/config/php/user-pool.conf /etc/php5/fpm/pool.d/$username.conf
sed -i "s/USERNAME/$username/g" /etc/php5/fpm/pool.d/$username.conf

/etc/init.d/php5-fpm restart

###----------------------------------------###
###  Configure NGINX Host
###----------------------------------------###
su - $username -c "cd ~/www && mkdir -p $domain/public_html;
echo 'It works!' > $domain/public_html/index.html"

cp $SCRIPT_PATH/config/nginx/user.conf /etc/nginx/sites-available/$username-$domain.conf
sed -i "s/USERNAME/$username/g" /etc/nginx/sites-available/$username-$domain.conf
sed -i "s/DOMAIN/$domain/g" /etc/nginx/sites-available/$username-$domain.conf

su - $username -c "touch ~/www/nginx.conf"

# Enable site
ln -s /etc/nginx/sites-available/$username-$domain.conf /etc/nginx/sites-enabled/$username-$domain.conf

/etc/init.d/nginx restart

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
