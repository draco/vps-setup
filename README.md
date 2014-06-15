# Important
- Only ever tested on Debian 7.5.
- This script assumes you are running it on a *new* server.

# To start
```
get --no-check-certificate https://github.com/draco/vps-setup/archive/debian-mysql.zip
unzip debian-mysql.zip
cd *debian-mysql
./setup.sh
```

# Scripts available

## `setup.sh`
**NOTE: Only run this on a new server**.

Currently this should _not be executed more than once_ on a server.

This script will by default:
- Create `sftponly` user group
- Set `PermitRootLogin without-password` in `sshd_config`.
 - Remember to add a user or setup ssh key for your root account.
- Add DotDeb repository
- Install `aptitude`/`git`/`curl`/`python-software-properties`
- Install `memcached`
- Install `ssmtp` (and `apticron`)
- Install `nginx`, `mysql`, `php5-fpm`

## `add_user.sh`
This script will:
- Create a new user and add to:
 - `mail` group if using sSMTP
 - `sftponly` group to force sFTP chroot (no ssh)
- Setup a PHP pool (each user runs php separately for security)
- Create a MySQL User and Database
- Create an nginx server block for their domain

# To-do
- Add `remove_user.sh`.
- Add `set_wordpress.sh`.
- Split the `.sh` files up for modularity.
