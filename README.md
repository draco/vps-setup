# Linux
- Only ever tested on Debian 7.5.

# Scripts available

`setup.sh`
**Only run this on a new server**.

This script will by default:
- Add DotDeb repository (for nginx, MySQL and php5-fpm)
- Install `aptitude`/`git`/`curl`/`python-software-properties`
- Install `memcached`
- Install `ssmtp` (and `apticron`)
- Install `nginx`, `mysql`, `php5-fpm`

`new_user.sh`
This script will:
- Create a new user
- Setup a PHP pool (each user runs php separately for security)
- Create a MySQL User and Database
- Create an nginx server block for their domain
