cd ~
wget --no-check-certificate -O debian.tar.gz https://github.com/draco/vps-setup/tarball/debian-mysql
tar -zxvf debian.tar.gz
sudo cd *vps-setup*
sudo sh setup.sh
