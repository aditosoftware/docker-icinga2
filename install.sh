#!/bin/sh

export DEBIAN_FRONTEND=noninteractive

#Initial install
apt update
apt upgrade -y
apt-get install -y --no-install-recommends apache2 ca-certificates curl dnsutils gnupg locales lsb-release mailutils mariadb-client mariadb-server php-curl php-ldap php-mysql procps pwgen supervisor unzip wget libdbd-mysql-perl

#Add icinga2 key
curl -s https://packages.icinga.com/icinga.key | apt-key add -
echo "deb http://packages.icinga.org/ubuntu icinga-$(lsb_release -cs) main" > /etc/apt/sources.list.d/icinga2.list
apt update
apt-get install -y --no-install-recommends icinga2 icinga2-ido-mysql icingacli icingaweb2 icingaweb2-module-doc icingaweb2-module-monitoring monitoring-plugins nagios-nrpe-plugin nagios-plugins-contrib nagios-snmp-plugins nsca

cat > /etc/icinga2/features-available/ido-mysql.conf << EOF
library "db_ido_mysql"
object IdoMysqlConnection "ido-mysql" {
  user = "root"
  password = "root"
  host = "localhost"
  database = "icinga2idomysql"
}
EOF

#Configure icinga2 ido-mysql
service mysql start
sleep 3
mysqladmin -u root password root
sleep 3
mysql -uroot -proot -e "CREATE DATABASE icinga2idomysql CHARACTER SET latin1 COLLATE latin1_general_ci;"
mysql -uroot -proot -e "update mysql.user set password=password('root') where user='root';"
mysql -uroot -proot -e "update mysql.user set plugin='' where user='root';"
mysql -uroot -proot -e "flush privileges;"
mysql -uroot -proot icinga2idomysql < /usr/share/icinga2-ido-mysql/schema/mysql.sql
echo "date.timezone =Europe/Berlin" >> /etc/php/7.2/apache2/php.ini

#enable ido
ln -s /etc/icinga2/features-available/ido-mysql.conf /etc/icinga2/features-available/ido-myql.conf
icinga2 feature enable ido-mysql

#enable apache mod
a2enmod rewrite

usermod -a -G icingaweb2 www-data;
icingacli setup config directory --group icingaweb2;
icinga2 api setup


#create icingaweb db
mysql -uroot -proot -e "CREATE DATABASE icingaweb;"
mysql -uroot -proot icingaweb < /usr/share/icingaweb2/etc/schema/mysql.schema.sql

#create user for icingaweb2
#icingaadmin:icinga
export pass=$(openssl passwd -1 icinga)
mysql -uroot -proot -e  "INSERT INTO icingaweb.icingaweb_user (name, active, password_hash) VALUES ('icingaadmin', 1, '$pass');"
#mysql -uroot -proot -e  "INSERT INTO icingaweb.icingaweb_group_membership (username) VALUES ('icingaadmin');"

#authentication.ini
cat > /etc/icingaweb2/authentication.ini << EOF
[icingaweb2]
  backend = "db"
  resource = "icingaweb_db"
EOF

# #config.ini
cat > /etc/icingaweb2/config.ini << EOF
[global]
  show_stacktraces = "1"
  show_application_state_messages = "1"
  config_backend = "db"
  config_resource = "icingaweb_db"

[logging]
  log = "syslog"
  level = "ERROR"
  application = "icingaweb2"
  facility = "user"
EOF

#groups.ini
cat > /etc/icingaweb2/groups.ini << EOF
[icingaweb2]
  backend = "db"
  resource = "icingaweb_db"
EOF

#resources.ini
cat > /etc/icingaweb2/resources.ini << EOF
[icingaweb_db]
  type = "db"
  db = "mysql"
  host = "localhost"
  port = "3306"
  dbname = "icingaweb"
  username = "root"
  password = "root"
  charset = "latin1"
  use_ssl = "0"

[icinga_ido]
  type = "db"
  db = "mysql"
  host = "localhost"
  port = "3306"
  dbname = "icinga2idomysql"
  username = "root"
  password = "root"
  charset = "latin1"
  use_ssl = "0"
EOF

#roles.ini
cat > /etc/icingaweb2/roles.ini << EOF
[Administrators]
  users = "icingaadmin"
  permissions = "*"
  groups = "Administrators"
EOF

# #Configuration Icingaweb Modules
mkdir -p /etc/icingaweb2/modules/monitoring
mkdir -p /etc/icingaweb2/enabledModules

#Enable Monitoring Modules
ln -s /usr/share/icingaweb2/modules/monitoring/ /etc/icingaweb2/enabledModules/monitoring

#backends.ini
cat > /etc/icingaweb2/modules/monitoring/backends.ini << EOF
[icinga]
  type = "ido"
  resource = "icinga_ido"
EOF

#commandtransports.ini
cat > /etc/icingaweb2/modules/monitoring/commandtransports.ini << EOF
[icinga2]
  transport = "api"
  host = "0.0.0.0"
  port = "5665"
  username = "root"
  password = "d2b4193d8549d6e4"
EOF

#config.ini
cat > /etc/icingaweb2/modules/monitoring/config.ini << EOF
[security]
  protected_customvars = "*pw*,*pass*,community"
EOF

#Module installation - Graphite, Director
#Director
# mkdir -p /usr/share/icingaweb2/modules/
# mkdir -p /usr/share/icingaweb2/modules/director/
# wget -q --no-cookies -O - https://github.com/Icinga/icingaweb2-module-director/archive/v1.4.3.tar.gz | tar xz --strip-components=1 --directory=/usr/share/icingaweb2/modules/director --exclude=.gitignore -f -
# ln -s /usr/share/icingaweb2/modules/director/ /etc/icingaweb2/enabledModules/director

#Graphite
mkdir -p /usr/share/icingaweb2/modules/graphite
wget -q --no-cookies -O - "https://github.com/Icinga/icingaweb2-module-graphite/archive/v1.0.1.tar.gz" | tar xz --strip-components=1 --directory=/usr/share/icingaweb2/modules/graphite -f -

rm /etc/icinga2/features-available/graphite.conf
#config will be written in run.sh
ln -s /usr/share/icingaweb2/modules/graphite/ /etc/icingaweb2/enabledModules/graphite

mkdir -p /etc/icingaweb2/modules/graphite

  #fix https://github.com/Icinga/icingaweb2-module-graphite/pull/171/files
  sed -i '33s/protected $handles/protected $handles = []/' /etc/icingaweb2/enabledModules/graphite/library/vendor/iplx/Http/Client.php
  sed -i '33s/$ch = $this->handles ? array_pop($this->handles) : curl_init()/$ch = ! empty($this->handles) ? array_pop($this->handles) : curl_init()/' /etc/icingaweb2/enabledModules/graphite/library/vendor/iplx/Http/Client.php

#graphite config will be enabled and wrote in run.sh

#Add NSCA Config
icinga2 feature enable command
sed -i 's#command_file.*#command_file=/run/icinga2/cmd/icinga2.cmd#g' /etc/nsca.cfg

#disable main log
icinga2 feature disable mainlog

#Add /icinga2conf
echo "include_recursive \"/icinga2conf\"" >> /etc/icinga2/icinga2.conf

apt clean
rm -rf /var/lib/apt/lists/*
