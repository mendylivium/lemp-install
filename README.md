# LEMP Install Script

This script automates the installation and configuration of NGINX, PHP, and MySQL on a Debian-based system. It also sets up a basic PHP application and optionally installs phpMyAdmin.

## Features

- Installs NGINX, PHP, MySQL
- Configures NGINX for a PHP application
- Optionally installs and configures phpMyAdmin
- Allows customization through command-line arguments

## Prerequisites

- Debian-based system (e.g., Ubuntu)
- Root or sudo privileges

## Usage

1. **Update Repo First:**

   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl gnupg

2. **Run This Script:**
    ```bash
    curl -sL https://raw.githubusercontent.com/mendylivium/lemp-install/master/install-lemp.sh | sudo bash -s
## Command-Line Arguments
- --db-pass=<password>: Set the MySQL root password (default: admin1234)
- --db-name=<database>: Set the name of the MySQL database (default: laravel)
- --app-name=<name>: Set the name of the application (default: laravel)
- --install-app=<extensions>: Space-separated list of additional packages to install (e.g., bcmath pdo)
- --install-php-ext=<extensions>: Space-separated list of PHP extensions to install (e.g., bcmath pdo)
- --install-phpmyadmin: Install and configure phpMyAdmin

## Example Usage
- Install Laravel and phpMyAdmin
```bash
curl -sL https://raw.githubusercontent.com/mendylivium/lemp-install/master/install-lemp.sh | sudo bash -s --install-php-ext="mbstring xmlrpc gd xml cli zip curl bcmath sqlite3" --install-app="pdo pdo_mysql" --install-phpmyadmin --install-laravel

