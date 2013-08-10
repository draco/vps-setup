VPS Scripts
==================

Originally forked from here: https://github.com/aristath/WordPress-Animalia

I've created a new repo, as this is not going to remain Wordpress specific. I plan to add scripts to provision node.js sites with nginx as well.

These scripts are intended to help significantly reduce the time it takes to setup a new VPS, manage it's configuration, and setup new users

Scripts available
=============

`setup.sh`
You'll want to run this first to provision a new server. This will install and configure: NGINX, MariaDB, PHP-FPM, and WP-CLI

The MariaDB repo settings are for Ubuntu 12.04 In fact, this has only been tested on Ubuntu 12.04

After running this, test to make sure the MySQL root password generated is working. Sometimes it won't reset via the script.

`mysql_reset.sh`
If the root MySQL password fails to be setup automatically, you can run this to generate one. This can also be used at anytime to randomly set a root password.

`new_user.sh`
This script will:
* Create a new user
* Setup a PHP pool (each user runs php separately for security)
* Create a MySQL User and Database
* Create an nginx server block for their domain
* Install and configure Wordpress Multisite

If you're looking for a one shot install everything including Wordpress, be sure to checkout @aristath's Wordpress Animalia script: https://github.com/aristath/WordPress-Animalia

Take care,

Alexander Rohmann