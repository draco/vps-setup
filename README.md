# What this does
- Setup a very basic nginx/MySQL/PHP7.2-FPM environment.
- Setup a simple mail interface with sSMTP.
- Setup users with mail, sudo and/or sftp-only access.
- Setup a SWAP file if it doesn't exist.

# Important
- Tested on Ubuntu 16.04 (server installation)
- These scripts assume you are running it on a **new** server as root.
- **I really only recommend using these scripts with VPS on OpenVZ virtualization to host simple blogs or non-critical apps.**

# To start
```
wget --no-check-certificate https://github.com/draco/vps-setup/archive/master.zip; unzip master.zip; cd master; ./setup.sh
```

# Scripts available
## `setup.sh`

This script will:
- Create a swap file the same size as the memory available (if none is detected but _this does not work on OpenVZ virtualization_).
- Create a `sftponly` user group.
- Set `PermitRootLogin without-password` in `sshd_config`.
- Install `git`/`curl`/`python-software-properties`/`expect`.
- Install `memcached`.
- Install `ssmtp` and `apticron`.
- Install `nginx`, `mysql`, `php7.2-fpm`.

## `add_user.sh`
This script will create:
- a new user and add to the following groups:
 - `mail` if granted sSMTP access.
 - `sftponly` if restricted to sFTP chroot.
 - `sudo` if granted sudo access.
- a PHP7.2-FPM pool (each user runs PHP separately for security).
- a MySQL user and database:
 - MySQL username and database name are the same as the account username.
- a nginx server block for their domain.
 - `sub.domain.com` will map to `/home/$username/www/sub.domain.com/public_html/`.
 - each user will be mapped to only one domain (and all its subdomains).

## `del_user.sh`
This script will:
- Undo all changes made by `add_user.sh`.
