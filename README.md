# Important
- Only ever tested on Debian 7.5.
- This script assumes you are running it on a *new* server.

# Scripts available

## `setup.sh`
**NOTE: Only run this on a new server**.

Currently this should _not be executed more than once_ on a server.

This script will by default:
- Add DotDeb repository (for nginx, MySQL and php5-fpm)
- Install `aptitude`/`git`/`curl`/`python-software-properties`
- Install `memcached`
- Install `ssmtp` (and `apticron`)
- Install `nginx`, `mysql`, `php5-fpm`

## `add_user.sh`
This script will:
- Create a new user (and add it to `mail` group to use sSMTP)
- Setup a PHP pool (each user runs php separately for security)
- Create a MySQL User and Database
- Create an nginx server block for their domain
