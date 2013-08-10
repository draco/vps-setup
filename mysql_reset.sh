cd ~
new_password=$(perl -le 'print map { (a..z,A..Z,0..9)[rand 62] } 0..pop' 36)
sudo service mysql stop
echo "UPDATE mysql.user SET Password=PASSWORD('${new_password}') WHERE User='root';" > ~/rootpassword.sql
echo "FLUSH PRIVILEGES;" >> rootpassword.sql
sudo mysqld_safe --init-file=${HOME}/rootpassword.sql &
sudo service mysql restart
sudo rm rootpassword.sql
cd -

echo "Root MySQL Password: $new_password"