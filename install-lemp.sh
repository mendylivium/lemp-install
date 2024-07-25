#!/bin/bash

# This script sets up a basic LAMP stack with optional components.
# Usage:
# ./script.sh [--db-pass=<password>] [--db-name=<dbname>] [--app-name=<appname>] 
#             [--install-app=<extensions>] [--install-php-ext=<php-extensions>]
#             [--install-phpmyadmin] [--for-laravel] [--install-laravel]

# Default values
DB_PASS="admin1234"
DB_NAME="laravel"
APP_NAME="laravel"
EXTENSIONS=""
PHP_EXTENSIONS=""
INSTALL_PHPMYADMIN=""
FOR_LARAVEL=""
INSTALL_LARAVEL=""

# Parse command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --db-pass=*)
      DB_PASS="${1#*=}"
      ;;
    --db-name=*)
      DB_NAME="${1#*=}"
      ;;
    --app-name=*)
      APP_NAME="${1#*=}"
      ;;
    --install-app=*)
      EXTENSIONS="${1#*=}"
      ;;
    --install-php-ext=*)
      PHP_EXTENSIONS="${1#*=}"
      ;;
    --install-phpmyadmin)
      INSTALL_PHPMYADMIN="true"
      ;;
    --for-laravel)
      FOR_LARAVEL="true"
      ;;
    --install-laravel)
      INSTALL_LARAVEL="true"
      ;;
    *)
      echo "Invalid argument: $1"
      exit 1
      ;;
  esac
  shift
done

# Ensure the script is run as root
if [ "$(id -u)" -ne "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Remove any existing NGINX installations
apt-get purge nginx nginx-common nginx-full -y

# Set non-interactive mode for apt-get
export DEBIAN_FRONTEND=noninteractive

# Configure MySQL
tee /tmp/mysql.conf <<EOF
# MySQL root password
mysql-server mysql-server/root_password password $DB_PASS
mysql-server mysql-server/root_password_again password $DB_PASS
EOF

# Apply MySQL configuration
sudo debconf-set-selections < /tmp/mysql.conf

# Update package list and install MySQL
apt update
apt-get install -y mysql-server

# Create the database if it doesn't exist
mysql -u root -p$DB_PASS -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"

# Install PHP and Composer
apt install -y php-fpm php-mysql curl

# Detect the installed PHP version
PHP_MAJOR_VERSION=$(php -r 'echo PHP_MAJOR_VERSION;')
PHP_MINOR_VERSION=$(php -r 'echo PHP_MAJOR_VERSION;')
PHP_VERSION="$PHP_MAJOR_VERSION.$PHP_MINOR_VERSION"

curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

export COMPOSER_ALLOW_SUPERUSER=1

# Configure Composer for PHP versions less than 8.0
if [ $PHP_MAJOR_VERSION -lt "8" ]; then
  composer config -g repo.packagist composer https://packagist.org
fi

# Install NGINX
apt install -y nginx

# Verify NGINX installation
if ! command -v nginx &> /dev/null; then
    echo "NGINX could not be installed."
    exit 1
fi

# Find the main NGINX configuration file
NGINX_CONF=$(nginx -t 2>&1 | grep -oP '(?<=configuration file ).*(?= test is successful)')

if [ -z "$NGINX_CONF" ]; then
    echo "NGINX configuration file could not be found."
    exit 1
fi

echo "NGINX configuration file located at: $NGINX_CONF"

# Configure NGINX
tee /etc/nginx/conf.d/default.conf <<EOF
server {
      listen 80;
      index index.php index.html;
      server_name _;
      root /var/www/$APP_NAME/public;

      location / {
          try_files \$uri \$uri/ ${FOR_LARAVEL:+/index.php?\$query_string} =404;
      }

      location ~ \.php$ {
          try_files \$uri =404;
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
          fastcgi_index index.php;
          include fastcgi_params;
          fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          fastcgi_param PATH_INFO \$fastcgi_path_info;
          fastcgi_param PHP_VALUE "auto_prepend_file= \n allow_url_include=Off";
      }
}
EOF

# Clean up old NGINX site configurations
rm -rf /etc/nginx/sites-enabled/*

# Install additional PHP extensions if specified
if [ -n "$EXTENSIONS" ]; then
  apt install -y $(echo $EXTENSIONS)
fi

# Install PHP extensions if specified
if [ -n "$PHP_EXTENSIONS" ]; then
  apt install -y $(echo $PHP_EXTENSIONS | sed "s/ / php-/g" | sed "s/^/php-/")
  echo "Installing PHP extensions: $PHP_EXTENSIONS"
fi

# Install phpMyAdmin if requested
if [ "$INSTALL_PHPMYADMIN" = "true" ]; then
  apt install -y phpmyadmin

  # Configure phpMyAdmin
  tee /etc/nginx/conf.d/phpmyadmin.conf <<EOF
server {
    listen 8080;
    index index.php index.html;
    server_name _;

    location /phpmyadmin {
        root /usr/share/;
        index index.php;
        try_files \$uri \$uri/ =404;
        location ~ \.php\$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\\.php)(/.+)\$;
            fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
        }
    }
}
EOF

  # Reload NGINX to apply the new phpMyAdmin configuration
  systemctl reload nginx
fi

# Set correct permissions for phpMyAdmin
chown -R www-data:www-data /usr/share/phpmyadmin

# Reload and restart NGINX
systemctl reload nginx
systemctl restart nginx

# Install Laravel if requested
if [ "$INSTALL_LARAVEL" = "true" ]; then
  if [ -d /var/www/$APP_NAME ]; then
      rm -rf /var/www/$APP_NAME
  fi
  composer create-project laravel/laravel /var/www/$APP_NAME
  chown -R www-data:www-data /var/www/$APP_NAME
  php /var/www/$APP_NAME/artisan key:generate
else
  # Set up a default PHP page
  mkdir -p /var/www/$APP_NAME/public

  tee /var/www/$APP_NAME/public/index.php <<EOF
<?php
echo "Using Appname<br/>";
phpinfo();
EOF

  tee /var/www/html/index.php <<EOF
<?php
echo "Using Default<br/>";
phpinfo();
EOF
fi
