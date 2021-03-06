#!/bin/bash
#set -e

MYSQLOLD="/var/lib/mysql"
MYSQLNEW="/mysql"
MYSQLCONF="/etc/mysql/mariadb.conf.d/50-server.cnf"

echo "$MYSQLOLD"
echo "$MYSQLNEW"

#Check folder /mysql. exit if not exist
if [ ! -d "$MYSQLNEW" ]; then
	echo "Folder $MYSQLNEW not found. Exit"
	exit 1
else
	cp -Rn $MYSQLOLD /
	echo "Copy $MYSQLOLD to /"

	#Change default path for mysql
	sed -i "s#datadir.*#datadir = /mysql#g" $MYSQLCONF

	#Change permissions icingaweb2 and icinga2 custom configuration folder
	echo "Change permissions of $MYSQLNEW to mysql:mysql"
	chown mysql:mysql -R $MYSQLNEW

	UP=$(ps aux | grep mysql | wc -l);
	if [ "$UP" -ne 2 ];
	then
		service mysql start
	else
		echo "cannot start mysql service"
		exit 1
	fi
fi

#write html redirect
rm -Rf /var/www/html/index.html
cat > /var/www/html/index.php << EOF
<?php
	header('Location: /icingaweb2');
?>
EOF

#Check env
#check Icingaadmin password
if [ -z "$ICINGA_PASS" ]; then
	export ICINGA_PASS="icinga"
	echo "Set icingaadmin pass to icinga"
else
	echo $ICINGA_PASS
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

#Check if /icinga2conf folder exist
if [[ ! -d /icinga2conf ]]; then
	echo "folder /icinga2conf not exist. Exit"
	exit 1
fi

#check if notifications.conf exist, if exist delete in /etc/icinga2
if [[ -s /icinga2conf/notifications.conf ]]; then
	rm /etc/icinga2/conf.d/notifications.conf
else
	mv /etc/icinga2/conf.d/notifications.conf /icinga2conf/notifications.conf

	interval=$(cat /icinga2conf/notifications.conf | grep interval | wc -l);
	if [ "$interval" -eq 2 ];
	then
		echo "Icinga2 check interval is set"
	else
		#Check if NOTIFICATION_INTERVAL is defined
		if [ -z "$NOTIFICATION_INTERVAL" ]; then
			echo "default"
		else
			sed -i "17i\interval = $NOTIFICATION_INTERVAL" /icinga2conf/notifications.conf
			sed -i "26i\interval = $NOTIFICATION_INTERVAL" /icinga2conf/notifications.conf
		fi
	fi
fi

#check apipass variable
if [ -z "$APIUSER" ]; then
	echo "API user not defined"
	icinga2 feature disable api
	rm -Rf /etc/icinga2/conf.d/api-users.conf
else
  echo "API user defined as ${APIUSER}"
  mkdir -p /etc/icingaweb2/modules/monitoring
	icinga2 feature enable api

		if [[ -s /icinga2conf/api-users.conf ]]; then
			rm /etc/icinga2/conf.d/api-users.conf
		else
			rm -Rf /etc/icinga2/conf.d/api-users.conf
			echo "object ApiUser \"$APIUSER\" {" > /icinga2conf/api-users.conf
			if [  -z "$APIPASS" ]; then
				echo "Password not defined, set default \"icingaapi2012m\""
				echo "password = \"icingaapi2012m\" " >> /icinga2conf/api-users.conf
			else
				echo "password = \"$APIPASS\" " >> /icinga2conf/api-users.conf
			fi
		
      echo " permissions = [ \"*\"]" >> /icinga2conf/api-users.conf
		  echo "}" >> /icinga2conf/api-users.conf
    fi 
  
  #create access data to use in icinga2 (to set acknowledge, downtime, etc)
  echo "[icinga2]" > /etc/icingaweb2/modules/monitoring/commandtransports.ini
  echo "  transport = \"api\" " >> /etc/icingaweb2/modules/monitoring/commandtransports.ini
  echo "  port = \"5665\" " >> /etc/icingaweb2/modules/monitoring/commandtransports.ini
  echo "  host = \"0.0.0.0\" " >> /etc/icingaweb2/modules/monitoring/commandtransports.ini
  echo "  username = \"$APIUSER\" " >> /etc/icingaweb2/modules/monitoring/commandtransports.ini
  echo "  password = \"$APIPASS\" " >> /etc/icingaweb2/modules/monitoring/commandtransports.ini
fi 
#check, if it's needed to disable service "swap" for monitoring host self
if [ "$SWAPSERVICEOFF" = "true" ] || [ "$SWAPSERVICEOFF" = "TRUE" ] || [ "$SWAPSERVICEOFF" = "1" ]; then
	sed -i '/apply Service "swap" {/','/}/d' /etc/icinga2/conf.d/services.conf
fi

#var to disable disk check 
if [ "$DISCSERVICEOFF" = "true" ] || [ "$DISCSERVICEOFF" = "TRUE" ] || [ "$DISCSERVICEOFF" = "1" ]; then
	sed -i '/apply Service for (disk => config in host.vars.disks) {/','/}/d' /etc/icinga2/conf.d/services.conf
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
	echo "        max_check_attempts = 2" >> /icinga2conf/passive.conf
	echo "        check_interval = 3m " >> /icinga2conf/passive.conf
	echo "        retry_interval = 0 " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        enable_active_checks = true " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        check_command = \"passive\" " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "	vars.notification[\"mail\"] = { " >> /icinga2conf/passive.conf
	echo "	groups = [ \"icingaadmins\" ] " >> /icinga2conf/passive.conf
	echo "	} " >> /icinga2conf/passive.conf
	echo "} " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "template Host \"passive-host\" { " >> /icinga2conf/passive.conf
	echo "        max_check_attempts = 2 " >> /icinga2conf/passive.conf
	echo "        check_interval = 3m " >> /icinga2conf/passive.conf
	echo "        retry_interval = 0 " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        enable_active_checks = true " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "        check_command = \"passive\" " >> /icinga2conf/passive.conf
	echo " " >> /icinga2conf/passive.conf
	echo "	vars.notification[\"mail\"] = { " >> /icinga2conf/passive.conf
	echo "	groups = [ \"icingaadmins\" ] " >> /icinga2conf/passive.conf
	echo "	} " >> /icinga2conf/passive.conf
	echo "} " >> /icinga2conf/passive.conf
fi

pass=$(openssl passwd -1 $ICINGA_PASS)
mysql -uroot -proot icingaweb -e "update icingaweb_user set password_hash='$pass' where name='icingaadmin';"
echo "configure icingaweb user $pass"

#Enable Graphite
if [ "$ENABLEGRAPHITE" = "true" ] || [ "$ENABLEGRAPHITE" = "TRUE" ] || [ "$ENABLEGRAPHITE" = "1" ]; then
cat > /etc/icingaweb2/modules/graphite/config.ini << EOF
[graphite]
url = "$GRAPHITE_TRANS://$GRAPHITE_WEBHOST:$GRAPHITE_WEBSITE_PORT"
user = "$GRAPHITE_USER"
password = "$GRAPHITE_PASS"
insecure = "$GRAPHITE_SECUR"
EOF
cat > /etc/icinga2/features-available/graphite.conf << EOF
library "perfdata"
object GraphiteWriter "graphite" {
  host = "$GRAPHITE_HOST"
  port = $GRAPHITE_PORT
  enable_send_thresholds = true
}
EOF
  
  icinga2 feature enable graphite

fi

if [ "$REMOVEDEFAULTSVC" = "true" ] || [ "$REMOVEDEFAULTSVC" = "TRUE" ] || [ "$REMOVEDEFAULTSVC" = "1" ]; then
  rm -rf /etc/icinga2/conf.d/services.conf
fi


#Change permissions icingaweb2 and icinga2 custom configuration folder
sed -i "s/vars.os.*/#vars.os = \"Linux\"/g" /etc/icinga2/conf.d/hosts.conf

#Restart service
service apache2 stop
service nsca stop
/etc/init.d/supervisor stop

#Start icinga2
service icinga2 start

rm /etc/init.d/apache2
rm /etc/init.d/nsca
rm /etc/init.d/supervisor

supervisord -n -c /etc/supervisor/supervisord.conf
