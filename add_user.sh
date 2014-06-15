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
read -p "Username to setup: " username
read -p "Domain for this site: " domain
read -p "Allow use of sSMTP?: (yN) " allow_smtp

###----------------------------------------###
###  Confirm Inputs
###----------------------------------------###
echo "You have entered:"
echo "Username: $username"
echo "Domain: $domain"
echo "Use sSMTP: $allow_smtp"
read -p "Are you 100% sure this is correct?: (yN)" confirmgo

if [ "$confirmgo" != "y" ] ; then
    echo "Better try again!"
    exit 1
fi
echo "Ok, here we go!"

###----------------------------------------###
###  Create User account
###----------------------------------------###
password=$(randstr 36)
sudo useradd -m -p $(perl -e 'print crypt($ARGV[0], "password")' $password) $username
echo "Created new username with username \"$username\""

#Create www folder and log folders
sudo su - $username -c "cd ~ && mkdir www;
mkdir -p logs/nginx;
"

###----------------------------------------###
###  Create MySQL User
###----------------------------------------###
db_user="${username:0:16}" #limit to first 16 characters - this will need to strip out special characters that are allowed in usernames like "-"
db_pass=$(randstr 36)

mysql --login-path=root --execute="CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
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

#create local nginx.conf as the user
sudo su - $username -c "touch ~/www/nginx.conf"

#enable site
sudo ln -s /etc/nginx/sites-available/$username-$domain.conf /etc/nginx/sites-enabled/$username-$domain.conf

sudo /etc/init.d/nginx restart

###----------------------------------------###
###  Create MySQL Database
###----------------------------------------###
db_name=$db_user

mysql --login-path=root --execute="CREATE DATABASE $db_name;GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
mysql --login-path=root --execute="FLUSH PRIVILEGES;"

###----------------------------------------###
### Allow to use sSMTP
###----------------------------------------###
if [ "$allow_smtp" = "y" ]; then
  echo "Adding $username to mail group..."
  sudo usermod --append --groups mail $username
fi

###----------------------------------------###
### Setting up for sFTP
###----------------------------------------###
echo "Adding $username to sftponly group..."
sudo usermod --append --groups sftponly $username
sudo chown root:sftponly /home/$username

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
