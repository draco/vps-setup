read -p "Username to delete: " username
read -p "Main domain associated: " domain

echo "You have chosen to delete user $username with domain $domain"
read -p "Are you sure? This cannot be undone: [y/N] " please_delete

if [ "$please_delete" = "y" ]; then
  echo "Removing MySQL account..."
  mysql --login-path=root --execute="DROP USER '$username'@'localhost';"
  mysql --login-path=root --execute="DROP DATABASE $username;"
  mysql --login-path=root --execute="FLUSH PRIVILEGES;"

  echo "Removing nginx config..."
  sudo rm /etc/nginx/sites-available/$username-$domain.conf
  sudo rm /etc/nginx/sites-enabled/$username-$domain.conf
  sudo /etc/init.d/nginx restart

  echo "Removing PHP-FPM config..."
  sudo rm /etc/php5/fpm/pool.d/$username.conf
  sudo /etc/init.d/php5-fpm restart
  if [[ `ps aux | grep -v grep | grep -c php-fpm` -eq 0 ]]; then
    test_error=$(sudo tail -3 /var/log/php5-fpm.log | head -1)
    if [[ `echo $test_error | grep -c  "No pool defined"` -ne 0 ]]; then
      echo "TIP: You need at least a user pool (create by using add_user.sh) to start php5-fpm."
    fi
  fi

  echo "Removing user, associated groups and home directory..."
  sudo chown $username:$username /home/$username/
  sudo usermod --groups "" $username
  sudo userdel --remove $username
fi
