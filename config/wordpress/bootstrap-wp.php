/* This PHP is run in Wordpress after it's installed */

//Enable nginx map by default.

$rt_wp_nginx_helper_global_options = get_site_option('rt_wp_nginx_helper_global_options');

$rt_wp_nginx_helper_global_options[ 'enable_map' ] = 1;
$rt_wp_nginx_helper_global_options[ 'enable_log' ] = 1;

update_site_option('rt_wp_nginx_helper_global_options', $rt_wp_nginx_helper_global_options);