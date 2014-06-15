# Important
- Only ever tested on Debian 7.5 on:
 - DigitalOcean (Debian 7.0 x32)
 - Vagrant (`config.vm.box = "puphpet/debian75-x32"`)
- This script assumes you are running it on a **new** server as root.

# To start
```
wget --no-check-certificate https://github.com/draco/vps-setup/archive/debian-mysql.zip; unzip debian-mysql.zip; cd *debian-mysql;  ./setup.sh
```

# Scripts available
## `setup.sh`
**NOTE:** this should _not be executed more than once_ on a server.

This script will by default:
- Create a swap file the same size as the memory available (if none is detected).
- Create `sftponly` user group.
- Set `PermitRootLogin without-password` in `sshd_config`.
- Add DotDeb repository.
- Install `aptitude`/`git`/`curl`/`python-software-properties`/`expect`.
- Install `memcached`.
- Install `ssmtp` (and `apticron` IFF `ssmtp` is installed).
- Install `nginx`, `mysql`, `php5-fpm`.

## `add_user.sh`
This script will:
- Create a new user and add to the following groups:
 - `mail` (if `ssmtp` is installed).
 - `sftponly` if restricted to sFTP chroot (no ssh).
- Setup a PHP pool (each user runs php separately for security).
- Create a MySQL user and database:
  - MySQL username and database name are the same as the account username.
- Create an nginx server block for their domain, supports wildcard sub-domains.
 - `sub.domain.com` will map to `/home/$username/www/sub.domain.com/public_html/`.

## `del_user.sh`
This script will:
- Undo all changes made by `add_user.sh`.

# To-do
- Split the `.sh` files up for modularity.
