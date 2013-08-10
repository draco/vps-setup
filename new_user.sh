#This will eventually be split into two scripts
# one to create the user, php pool and database user
# and one to add a new domain for that user (the first one can add a default/first domain by nesting this script)


###----------------------------------------###
###  Functions
###----------------------------------------###

#Generates a random string of a given length -> $ randstr 16
function randstr {
    echo $(perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..pop' $1)
}

###----------------------------------------###
###  Prompt User
###----------------------------------------###

echo "What username would you like to setup?"
read username
echo "What is the domain for this site?"
read domain
echo 'What is the MySQL root password?'
read -s mysql_root

#Wordpress info

echo "Wordpress Admin username: [admin]"
read wp_admin
echo "Wordpress Admin Email: [admin@$domain]"
read wp_email
echo "Wordpress Site Title: [$domain]"
read wp_title


###----------------------------------------###
###  Input Validation / Defaults
###----------------------------------------###

if [ "$wp_admin" == "" ] ; then
    wp_admin="admin"
fi
if [ "$wp_email" == "" ] ; then
    wp_email="admin@$domain"
fi
if [ "$wp_title" == "" ] ; then
    wp_title=$domain
fi

wp_url="http://$domain/"
wp_password=$(randstr 36)

###----------------------------------------###
###  Confirm Inputs
###----------------------------------------###

# Confirm inputed information
echo "You have entered:"
echo "Username: $username"
echo "Domain: $domain"
echo "MySQL root password: [hidden - hope you entered it right...]"
echo "Are you 100% sure this is correct? [yN]"
read confirmgo

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

#Create public_html folder and log folders
sudo su - $username -c "cd ~ && mkdir public_html;
mkdir -p logs/nginx;
"

###----------------------------------------###
###  Create MySQL User
###----------------------------------------###

db_user="${username:0:16}" #limit to first 16 characters - this will need to strip out special characters that are allowed in usernames like "-"
db_pass=$(randstr 36)

mysql -u root --password=$mysql_root -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
mysql -u root --password=$mysql_root -e "FLUSH PRIVILEGES;"

###----------------------------------------###
###  Setup PHP Pool
###----------------------------------------###

sudo cp config/php/user-pool.conf /etc/php5/fpm/pool.d/$username.conf
sudo sed -i "s/USERNAME/$username/g" /etc/php5/fpm/pool.d/$username.conf

sudo service php5-fpm stop
sudo service php5-fpm start

### Begin Domain Specific Configuration

###----------------------------------------###
###  Configure NGINX Host
###----------------------------------------###

# Create virtual host

sudo su - $username -c "cd ~/public_html && mkdir $domain; echo 'It works!' > $domain/index.html"

site_root="/home/$username/public_html/$domain"

sudo cp config/nginx/user.conf /etc/nginx/sites-available/$username-$domain.conf
sudo sed -i "s/USERNAME/$username/g" /etc/nginx/sites-available/$username-$domain.conf
sudo sed -i "s/DOMAIN/$domain/g" /etc/nginx/sites-available/$username-$domain.conf

#create local nginx.conf as the user
sudo su - $username -c "touch $site_root/nginx.conf"

#enable site
sudo ln -s /etc/nginx/sites-available/$username-$domain.conf /etc/nginx/sites-enabled/$username-$domain.conf

###----------------------------------------###
###  Create MySQL Database
###----------------------------------------###

db_name=$db_user

mysql -u root --password=$mysql_root -e "CREATE DATABASE $db_name;GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
mysql -u root --password=$mysql_root -e "FLUSH PRIVILEGES;"

###----------------------------------------###
###  Install Wordpress (Multisite)
###----------------------------------------###

$wp_bootstrap=$(<config/wordpress/bootstrap-wp.php);
#Run the install as the user so file ownership is setup properly
sudo su - $username -c "cd public_html/$domain;
wp core download;
wp core config --dbname=$db_name --dbuser=$db_user --dbpass=$db_pass;
wp core multisite-install --url=$wp_url --title=\"$wp_title\" --admin_name=$wp_admin --admin_password=$wp_password --admin_email=$wp_email;
wp plugin install nginx-helper --force
wp plugin activate nginx-helper -network
touch /home/$username/public_html/$domain/wp-content/uploads/nginx-helper/map.conf;
wp eval '$wp_bootstrap' "

sudo service nginx reload

###----------------------------------------###
###  Harden WordPress Permissions
###----------------------------------------###

# reset to safe defaults
find $site_root -type d -exec sudo chmod 755 {} \;
find $site_root -type f -exec sudo chmod 644 {} \;
 
# allow wordpress to manage wp-config.php (but prevent world access)
sudo chmod 660 $site_root/wp-config.php
 
# allow wordpress to manage wp-content
find $site_root/wp-content -type d -exec sudo chmod 775 {} \;
find $site_root/wp-content -type f -exec sudo chmod 664 {} \;

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
echo "| Wordpress Admin: $wp_admin"
echo "| Wordpress Password: $wp_password"
echo "+------------------------------------+"
