#!/bin/bash
#set -e

MYSQLOLD="/var/lib/mysql"
MYSQLNEW="/mysql"

#Change depricated mysql config
sed -i 's/key_buffer*/key_buffer_size/g' /etc/mysql/my.cnf

#Check folder /mysql. exit if not exist
if [ ! -d "$MYSQLNEW" ]; then
	echo "Folder $MYSQLNEW not found. Exit"
	exit 1
else
	cp -R $MYSQLOLD /
	
	#Change permissions icingaweb2 and icinga2 custom configuration folder
	chown mysql:mysql -R $MYSQLNEW
	
	if [ ! -d "$MYSQLNEW/mysql" ]; then
		cp -R $MYSQLOLD/mysql $MYSQLNEW
	fi
	if [ ! -d "$MYSQLNEW/graphite" ]; then
		cp -R $MYSQLOLD/graphite $MYSQLNEW/
	fi
	if [ ! -d "$MYSQLNEW/icinga2idomysql" ]; then
		cp -R $MYSQLOLD/icinga2idomysql $MYSQLNEW/
	fi
	if [ ! -d "$MYSQLNEW/icingaweb" ]; then
		cp -R $MYSQLOLD/icingaweb $MYSQLNEW/
	fi
	
	#Change default path for mysql 
	sed -i "s#datadir.*#datadir = /mysql#g" /etc/mysql/my.cnf
	
	#Start MYSQL
	service mysql restart
	
	UP=$(ps aux | grep mysql | wc -l);
	if [ "$UP" -ne 2 ];
	then
		service mysql restart
	else
		echo "cannot start mysql service"
	fi
fi

#Check env
#check Icingaadmin password
if [ -z "$ICINGA_PASS" ]; then
	export ICINGA_PASS="icinga"
	echo "Set icingaadmin pass to icinga"
else
	echo $ICINGA_PASS
fi
#check graphitehost variable
if [ -z "GRAPHITE_HOST" ]; then
	echo "Graphite Host not defined.Exit"
	exit 1
else
	echo $GRAPHITE_HOST
fi
#check mailserver variable
if [ -z "MAILSERVER" ]; then
	echo "Mailserver not defined"
else
	#Define mailsend command and write this to /etc/icinga2/scripts/mail-host-notification.sh
	sed -i 's#/usr/bin/.*#/usr/bin/printf \"%b\" \"$template\" | mailx -r '\"monitoring@$HOSTNAME\"' -s \"$NOTIFICATIONTYPE - $HOSTDISPLAYNAME is $HOSTSTATE\" -S smtp='\"$MAILSERVER\"' $USEREMAIL#g' /etc/icinga2/scripts/mail-host-notification.sh
  sed -i 's#/usr/bin/.*#/usr/bin/printf \"%b\" \"$template\" | mailx -r '\"monitoring@$HOSTNAME\"' -s \"$NOTIFICATIONTYPE - $HOSTDISPLAYNAME - $SERVICEDISPLAYNAME is $SERVICESTATE\" -S smtp='\"$MAILSERVER\"' $USEREMAIL#g' /etc/icinga2/scripts/mail-service-notification.sh
fi
#check email variable
if [ -z "$EMAILADDR" ]; then
	echo "Email for icingaadmin not defined"
else
	sed -i "11s/.*/enable_notifications = true/g" /etc/icinga2/conf.d/users.conf
	sed -i 's/'"root@localhost"'/'"$EMAILADDR"'/' /etc/icinga2/conf.d/users.conf

fi
#check if NSCA Password is defined
if [ -z "$NSCAPASS" ]; then
	echo "nsca password not defined"
else
	echo "password=$NSCAPASS" >> /etc/nsca.cfg
fi
#check if NSCA Port ist defined. If not define set stardardport 5667
if [ -z "$NSCAPORT" ]; then
	sed -i "s/server_port.*/server_port=5667/g" /etc/nsca.cfg
else
	sed -i "s/server_port.*/server_port=$NSCAPORT/g" /etc/nsca.cfg
fi

#Check if /icingaweb2 folder exist
if [[ ! -d /icingaweb2 ]]; then
	echo "folder /icingaweb2 not exist. Exit"
	exit 1
fi

if [[ -s /icingaweb2/resources.ini ]]; then
	rm /etc/icingaweb2/resources.ini
	ln -s /icingaweb2/resources.ini /etc/icingaweb2/resources.ini
else
	cp /etc/icingaweb2/resources.ini /icingaweb2/resources.ini
	rm /etc/icingaweb2/resources.ini
	ln -s /icingaweb2/resources.ini /etc/icingaweb2/resources.ini
fi
if [[ -s /icingaweb2/authentication.ini ]]; then
	rm /etc/icingaweb2/authentication.ini
	ln -s /icingaweb2/authentication.ini /etc/icingaweb2/authentication.ini
else
	cp /etc/icingaweb2/authentication.ini /icingaweb2/authentication.ini
	rm /etc/icingaweb2/authentication.ini
	ln -s /icingaweb2/authentication.ini /etc/icingaweb2/authentication.ini
fi
if [[ -s /icingaweb2/roles.ini ]]; then
	rm /etc/icingaweb2/roles.ini
	ln -s /icingaweb2/roles.ini /etc/icingaweb2/roles.ini
else
	cp /etc/icingaweb2/roles.ini /icingaweb2/roles.ini
	rm /etc/icingaweb2/roles.ini
	ln -s /icingaweb2/roles.ini /etc/icingaweb2/roles.ini
fi
if [[ -s /icingaweb2/groups.ini ]]; then
	rm /etc/icingaweb2/groups.ini
	ln -s /icingaweb2/groups.ini /etc/icingaweb2/groups.ini
else
	cp /etc/icingaweb2/groups.ini /icingaweb2/groups.ini
	rm /etc/icingaweb2/groups.ini
	ln -s /icingaweb2/groups.ini /etc/icingaweb2/groups.ini
fi

#check if AD Auth is enabled
if [[ $ENABLE_AD_AUTH -eq "1" ]]; then
	#Add AD Auth (resources.ini)
	echo "[ad]" >> /icingaweb2/resources.ini
	echo "type            = \"ldap\"" >> /icingaweb2/resources.ini
	echo "hostname        = \"$AD_NAME\"" >> /icingaweb2/resources.ini
	echo "port            = \"389\" " >> /icingaweb2/resources.ini
	echo "root_dn         = \"$AD_ROOT_DN\"" >> /icingaweb2/resources.ini
	echo "bind_dn         = \"$AD_BIND_DN\"" >> /icingaweb2/resources.ini
	echo "bind_pw         = \"$AD_BIND_PW\"" >> /icingaweb2/resources.ini
	
	echo "[AD]" >> /icingaweb2/authentication.ini
	echo "resource = \"ad\" " >> /icingaweb2/authentication.ini
	echo "backend = \"msldap\" " >> /icingaweb2/authentication.ini
	
	echo "[ad]" >> /icingaweb2/resources.ini
	echo " type            = \"ldap\"" >> /icingaweb2/resources.ini
	echo "hostname        = \"$AD_NAME\"" >> /icingaweb2/resources.ini
	echo "port            = \"389\" " >> /icingaweb2/resources.ini
	echo "root_dn         = \"$AD_ROOT_DN\"" >> /icingaweb2/resources.ini
	echo "bind_dn         = \"$AD_BIND_DN\"" >> /icingaweb2/resources.ini
	echo "bind_pw         = \"$AD_BIND_PW\"" >> /icingaweb2/resources.ini

	#Add authentication.ini
	echo "[AD]" >> /icingaweb2/resources.ini
	echo "resource = \"ad\" " >> /icingaweb2/authentication.ini
	echo "backend = \"msldap\" " >> /icingaweb2/authentication.ini
fi

if [[ ! -s /icinga2conf/users.conf ]]; then
	mv /etc/icinga2/conf.d/users.conf /icinga2conf/users.conf
else
	rm -f /etc/icinga2/conf.d/users.conf
fi

if [[ ! -s /icinga2conf/passive.conf ]]; then
	#Icinga2 Passive Check template (Host and Service)
	echo "template Service \"passive-service\" { " > /icinga2conf/passive.conf
	echo "        max_check_attempts = 1" >> /icinga2conf/passive.conf
	echo "        retry_interval = 1m " >> /icinga2conf/passive.conf
	echo "        check_interval = 1m " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        enable_active_checks = false " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        check_command = \"dummy\" " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        vars.dummy_state = 2 " >> /icinga2conf/passive.conf
	echo "        vars.dummy_text = \"No Passive Check Result Received.\" " >> /icinga2conf/passive.conf
	echo "	vars.notification[\"mail\"] = { " >> /icinga2conf/passive.conf
	echo "	groups = [ \"icingaadmins\" ] " >> /icinga2conf/passive.conf
	echo "	} " >> /icinga2conf/passive.conf
	echo "} " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "template Host \"passive-host\" { " >> /icinga2conf/passive.conf
	echo "        max_check_attempts = 1 " >> /icinga2conf/passive.conf
	echo "        retry_interval = 1m " >> /icinga2conf/passive.conf
	echo "        check_interval = 2m " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        enable_active_checks = false " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        check_command = \"dummy\" " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        vars.dummy_state = 2 " >> /icinga2conf/passive.conf
	echo "        vars.dummy_text = \"No Passive Check Result Received.\" " >> /icinga2conf/passive.conf
	echo "	vars.notification[\"mail\"] = { " >> /icinga2conf/passive.conf
	echo "	groups = [ \"icingaadmins\" ] " >> /icinga2conf/passive.conf
	echo "	} " >> /icinga2conf/passive.conf
	echo "} " >> /icinga2conf/passive.conf
fi

#Set password for icinga2-classicui (http://server.local/icinga2-classicui
htpasswd -b /etc/icinga2-classicui/htpasswd.users icingaadmin $ICINGA_PASS
#Generate password hash for icingaweb user (http://server.local/icinga2-classicui)
pass=$(openssl passwd -1 $ICINGA_PASS)

#Update Icingaweb2 user password
echo "update icingaweb_user set password_hash='$pass' where name='icingaadmin';" >> ~/userupdate.sql
mysql -u root -proot icingaweb < ~/userupdate.sql
rm -f ~/userupdate.sql

#Change Graphite host
sed -i "s#base.*#base_url=http://$GRAPHITE_HOST/render?#" /etc/icingaweb2/modules/graphite/config.ini

#Change permissions icingaweb2 and icinga2 custom configuration folder
sed -i "s/vars.os.*/#vars.os = \"Linux\"/g" /etc/icinga2/conf.d/hosts.conf

#Restart service
service apache2 restart
service icinga2 restart
service carbon-cache restart

exec nsca -c /etc/nsca.cfg -f --daemon