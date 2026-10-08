#!/bin/bash
# db01: MariaDB with the vprofile "accounts" database
set -e
DATABASE_PASS='admin123'

dnf update -y
dnf install -y epel-release
dnf install -y git zip unzip mariadb-server

systemctl start mariadb
systemctl enable mariadb

# Get the SQL dump from the vprofile repo
cd /tmp
rm -rf vprofile-project
git clone -b local https://github.com/hkhcoder/vprofile-project.git

# Secure MariaDB (same as mysql_secure_installation)
mysqladmin -u root password "$DATABASE_PASS"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$DATABASE_PASS" -e "DROP DATABASE IF EXISTS test"

# Create database + app user, load tables
mysql -u root -p"$DATABASE_PASS" -e "CREATE DATABASE IF NOT EXISTS accounts"
mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'localhost' IDENTIFIED BY 'admin123'"
mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'%' IDENTIFIED BY 'admin123'"
mysql -u root -p"$DATABASE_PASS" accounts < /tmp/vprofile-project/src/main/resources/db_backup.sql
mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"
systemctl restart mariadb

# Firewall: allow MySQL port
systemctl enable --now firewalld
firewall-cmd --permanent --add-port=3306/tcp
firewall-cmd --reload
