echo ""
echo "Deleting a user..."
echo ""
read -p "Username: " username
read -p "Domain name associated: " domain

echo "You have chosen to delete user $username with domain $domain"
read -p "Are you sure? This cannot be undone [y/N] " please_delete

if [ "$please_delete" = "y" ]; then
  echo "Removing MySQL account..."
  mysql --login-path=root --execute="DROP USER '$username'@'localhost';"
  mysql --login-path=root --execute="DROP DATABASE $username;"
  mysql --login-path=root --execute="FLUSH PRIVILEGES;"

  echo "Removing nginx config..."
  rm /etc/nginx/sites-available/$username-$domain.conf
  rm /etc/nginx/sites-enabled/$username-$domain.conf
  /etc/init.d/nginx restart

  echo "Removing PHP-FPM config..."
  rm /etc/php/7.2/fpm/pool.d/$username.conf
  /etc/init.d/php7.2-fpm restart
  if [[ `ps aux | grep -v grep | grep -c php-fpm` -eq 0 ]]; then
    test_error=$(tail -3 /var/log/php7.2-fpm.log | head -1)
    if [[ `echo $test_error | grep -c  "No pool defined"` -ne 0 ]]; then
      echo "TIP: You need at least a user pool (create by using add_user.sh) to start php7.2-fpm."
    fi
  fi

  echo "Removing user, associated groups and home directory..."
  chown $username:$username /home/$username/
  usermod --groups "" $username
  userdel --remove $username
fi

