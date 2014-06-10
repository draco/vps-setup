cd ~
MYSQL_ROOT_PASSWORD=$(perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..pop' 36)
sudo /etc/init.d/mysql stop
echo "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';" > rootpassword.sql
echo "FLUSH PRIVILEGES;" >> rootpassword.sql
sudo mysqld_safe --init-file=${HOME}/rootpassword.sql &
expect -c "
spawn mysql_config_editor set --login-path=root --host=localhost --user=root --password
expect -nocase \"Enter password:\" {send \"$MYSQL_ROOT_PASSWORD\r\"; interact}
"
cd -
