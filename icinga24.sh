#!/bin/bash
# Olaf Assmus
# optimiert Ubuntu 14.04.02 LTS x64
#
# Version 1.2.0
# 09.04.15

ICINGA_PASS="icinga"

#Icinga-trusty i386 amd64
apt-get update
apt-get install python-software-properties software-properties-common apache2 vim heirloom-mailx nsca -y
add-apt-repository ppa:formorer/icinga -y

# Patchen des Systems

apt-get update
apt-get upgrade -y

# Installation icinga2
apt-get install icinga2 -y
apt-get install nagios-nrpe-plugin --no-install-recommends -y

#Add /icinga2conf
echo "include_recursive \"/icinga2conf\"" >> /etc/icinga2/icinga2.conf

#Automatatic Install MySQL
export DEBIAN_FRONTEND=noninteractive
apt-get -q -y install mysql-server

#disable innodb
sed -i '34s/#.*/ignore-builtin-innodb/g' /etc/mysql/my.cnf
sed -i '33s/#.*/default-storage-engine = myisam/g' /etc/mysql/my.cnf

service mysql start

#service mysql start
mysqladmin -u root password root

#Use Standard IDO Inst.
apt-get install icinga2-ido-mysql -y

mysql -uroot -proot -e "create database icinga2idomysql;"

mysql -uroot -proot icinga2idomysql < /usr/share/icinga2-ido-mysql/schema/mysql.sql

touch /etc/icinga2/features-available/ido-mysql.conf
echo 'library "db_ido_mysql"' > /etc/icinga2/features-available/ido-mysql.conf
echo 'object IdoMysqlConnection "ido-mysql" {' >> /etc/icinga2/features-available/ido-mysql.conf
echo ' user = "root",' >> /etc/icinga2/features-available/ido-mysql.conf
echo ' password = "root",' >> /etc/icinga2/features-available/ido-mysql.conf
echo ' host = "localhost",' >> /etc/icinga2/features-available/ido-mysql.conf
echo ' database = "icinga2idomysql"' >> /etc/icinga2/features-available/ido-mysql.conf
echo '} ' >> /etc/icinga2/features-available/ido-mysql.conf

icinga2 feature enable ido-mysql
mkdir -p /icinga2conf
/etc/init.d/icinga2 restart

#In order for queries and commands to work you will need to add your query user (e.g. your web server) to the icingacmd group
#(The Debian packages use nagios as the user and group name. Make sure to change icingacmd to nagios if you're using Debian.):

usermod -a -G nagios www-data

service icinga2 restart

apt-get install icinga2-classicui -y

#Add User root to htpasswd.root. Pass root
htpasswd -cb /icinga2conf/htpasswd.users icingaadmin $ICINGA_PASS
ln -s /icinga2conf/htpasswd.users /etc/icinga2-classicui/htpasswd.users

#Classic UI Installation
#http://localhost/icinga2-classicui/
#Login:icingaadmin
#Password:xxxxxxxx

#---------------------------------------------------------------------------------------------------
#Icinga Web 2 installation
apt-get install make apache2 git zend-framework libapache2-mod-php php-mcrypt apache2-utils php-mysql php-ldap -y
#Fehler "AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 127.0.1.1." unterdrücken
echo "ServerName localhost" >> /etc/apache2/apache2.conf

a2enmod cgi
a2enmod rewrite
service apache2 restart

#Zendframework in den php.ini anpassen
echo "include_path = ".:/usr/share/php:/usr/share/php/libzend-framework-php/"" >> /etc/php/7.0/cli/php.ini
echo "include_path = ".:/usr/share/php:/usr/share/php/libzend-framework-php/"" >> /etc/php/7.0/apache2/php.ini

#IcingaWeb2 Git Download
cd /usr/src/
git clone https://github.com/Icinga/icingaweb2.git

#Anlegen der IcingaWeb2 mysql Datenbank
echo > ~/icingaweb2db.sql
echo "CREATE DATABASE icingaweb;" >> ~/icingaweb2db.sql
echo "CREATE USER icingaweb@localhost IDENTIFIED BY 'icingaweb';" >> ~/icingaweb2db.sql
echo "GRANT ALL PRIVILEGES ON icingaweb.* TO icingaweb@localhost;" >> ~/icingaweb2db.sql
echo "FLUSH PRIVILEGES;" >> ~/icingaweb2db.sql

mysql -u root -proot < ~/icingaweb2db.sql

#Schema import
echo Schema import /icingaweb2/etc/schema/mysql.schema.sql
mysql -u root -proot icingaweb < /usr/src/icingaweb2/etc/schema/mysql.schema.sql

cd /usr/src/
mv icingaweb2 /usr/share/icingaweb2
/usr/share/icingaweb2/bin/icingacli setup config webserver apache --document-root /usr/share/icingaweb2/public > /etc/apache2/conf-available/icingaweb2.conf

addgroup --system icingaweb2
usermod -a -G icingaweb2 www-data

a2enconf icingaweb2.conf
service apache2 reload

/usr/share/icingaweb2/bin/icingacli setup config directory

#It is required that a default timezone has been set using date.timezone in /etc/php5/apache2/php.ini.
#Change to date.timezone =Europe/Berlin
echo "date.timezone =Europe/Berlin" >> /etc/php/7.0/apache2/php.ini

service apache2 restart

#Generate Icingaweb2 Configuration
pass=$(openssl passwd -1 $ICINGA_PASS)

echo "INSERT INTO icingaweb_user (name, active, password_hash) VALUES ('icingaadmin', 1, '$pass');" >> ~/usergen.sql
echo "INSERT INTO icingaweb_group_membership (group_id, username) VALUES ('1', 'icingaadmin');" >> ~/usergen.sql
mysql -u root -proot icingaweb < ~/usergen.sql
rm -Rf ~/usergen.sql

#authentication.ini
echo "[icingaweb2]" > /etc/icingaweb2/authentication.ini
echo 'backend = "db"' >> /etc/icingaweb2/authentication.ini
echo 'resource = "icingaweb_db"' >> /etc/icingaweb2/authentication.ini

#config.ini
echo '[global]' > /etc/icingaweb2/config.ini
echo 'show_stacktraces = "1"' >> /etc/icingaweb2/config.ini
echo 'config_backend = "db"' >> /etc/icingaweb2/config.ini
echo 'config_resource = "icingaweb_db"' >> /etc/icingaweb2/config.ini
echo '[logging] ' >> /etc/icingaweb2/config.ini
echo 'log = "syslog" ' >> /etc/icingaweb2/config.ini
echo 'level = "ERROR" ' >> /etc/icingaweb2/config.ini
echo 'application = "icingaweb2"' >> /etc/icingaweb2/config.ini

#groups.ini
echo '[icingaweb2]' > /etc/icingaweb2/groups.ini
echo 'backend = "db" ' >> /etc/icingaweb2/groups.ini
echo 'resource = "icingaweb_db" ' >> /etc/icingaweb2/groups.ini

#resources.ini
echo '[icingaweb_db]' > /etc/icingaweb2/resources.ini
echo 'type = "db"' >> /etc/icingaweb2/resources.ini
echo 'db = "mysql"' >> /etc/icingaweb2/resources.ini
echo 'host = "localhost"' >> /etc/icingaweb2/resources.ini
echo 'port = "3306"' >> /etc/icingaweb2/resources.ini
echo 'dbname = "icingaweb"' >> /etc/icingaweb2/resources.ini
echo 'username = "root"' >> /etc/icingaweb2/resources.ini
echo 'password = "root"' >> /etc/icingaweb2/resources.ini
echo 'persistent = "0"' >> /etc/icingaweb2/resources.ini

echo '[icinga_ido]' >> /etc/icingaweb2/resources.ini
echo 'type = "db"' >> /etc/icingaweb2/resources.ini
echo 'db = "mysql"' >> /etc/icingaweb2/resources.ini
echo 'host = "localhost"' >> /etc/icingaweb2/resources.ini
echo 'port = "3306"' >> /etc/icingaweb2/resources.ini
echo 'dbname = "icinga2idomysql"' >> /etc/icingaweb2/resources.ini
echo 'username = "root"' >> /etc/icingaweb2/resources.ini
echo 'password = "root"' >> /etc/icingaweb2/resources.ini
echo 'persistent = "0"' >> /etc/icingaweb2/resources.ini

#roles.ini
echo '[Administrators]' > /etc/icingaweb2/roles.ini
echo 'users = "icingaadmin"' >> /etc/icingaweb2/roles.ini
echo 'permissions = "*"' >> /etc/icingaweb2/roles.ini
echo 'groups = "Administrators"' >> /etc/icingaweb2/roles.ini

#Configuration Icingaweb Modules
mkdir -p /etc/icingaweb2/modules/monitoring
mkdir -p /etc/icingaweb2/enabledModules

#backends.ini
echo '[icinga]' > /etc/icingaweb2/modules/monitoring/backends.ini
echo 'type = "ido" ' >> /etc/icingaweb2/modules/monitoring/backends.ini
echo 'resource = "icinga_ido" ' >> /etc/icingaweb2/modules/monitoring/backends.ini

#commandtransports.ini
echo '[icinga2]' > /etc/icingaweb2/modules/monitoring/commandtransports.ini
echo 'transport = "local"' >> /etc/icingaweb2/modules/monitoring/commandtransports.ini
echo 'path = "/var/run/icinga2/cmd/icinga2.cmd"' >> /etc/icingaweb2/modules/monitoring/commandtransports.ini

#config.ini
echo '[security]' > /etc/icingaweb2/modules/monitoring/config.ini
echo 'protected_customvars = "*pw*,*pass*,community"' >> /etc/icingaweb2/modules/monitoring/config.ini

#Enable Monitoring Modules
ln -s /usr/share/icingaweb2/modules/monitoring/ /etc/icingaweb2/enabledModules/monitoring
ln -s /usr/share/icingaweb2/modules/iframe/ /etc/icingaweb2/enabledModules/iframe

###################################################### Icinga2 Graphite Modul Installation ######################################################

#Enable Graphite feature
icinga2 feature enable graphite
/etc/init.d/icinga2 restart

#Install Graphite Icinga2 Modul
cd /usr/share/icingaweb2/modules
git clone https://github.com/findmypast/icingaweb2-module-graphite.git
mv /usr/share/icingaweb2/modules/icingaweb2-module-graphite/ /usr/share/icingaweb2/modules/graphite
rm /etc/icinga2/features-available/graphite.conf
touch /etc/icinga2/features-available/graphite.conf
echo 'library "perfdata"' >> /etc/icinga2/features-available/graphite.conf
echo 'object GraphiteWriter "graphite" {' >> /etc/icinga2/features-available/graphite.conf
echo 'host = "127.0.0.1"' >> /etc/icinga2/features-available/graphite.conf
echo 'port = 2003' >> /etc/icinga2/features-available/graphite.conf
echo '}' >> /etc/icinga2/features-available/graphite.conf
ln -s /usr/share/icingaweb2/modules/graphite/ /etc/icingaweb2/enabledModules/graphite

#Graphite Configuration
mkdir /etc/icingaweb2/modules/graphite
touch /etc/icingaweb2/modules/graphite/config.ini
echo "[graphite]" > /etc/icingaweb2/modules/graphite/config.ini
echo 'metric_prefix = icinga2' >> /etc/icingaweb2/modules/graphite/config.ini
echo "base_url = http://graphite.host/render?" >> /etc/icingaweb2/modules/graphite/config.ini
echo 'service_name_template = "icinga2.$host.name$.services.$service.name$.$service.check_command$.perfdata.$metric$.value"' >> /etc/icingaweb2/modules/graphite/config.ini
echo 'host_name_template = "icinga2.$host.name$.host.$host.check_command$.perfdata.$metric$.value"' >> /etc/icingaweb2/modules/graphite/config.ini
echo 'graphite_args_template = "&target=$target$&source=0&width=300&height=120&hideAxes=true&lineWidth=2&hideLegend=true&colorList=049BAF"' >> /etc/icingaweb2/modules/graphite/config.ini

#NSCA /var/run/icinga2/cmd/icinga2.cmd
sed -i 's#command_file.*#command_file=/var/run/icinga2/cmd/icinga2.cmd#g' /etc/nsca.cfg

#Create Redirecto to /icingaweb2
rm /var/www/html/index.html
cat <<EOF >/var/www/html/index.php
<?php
/* Redirect browser */
header("Location: /icingaweb2/");
exit;
?>
EOF

unset DEBIAN_FRONTEND
