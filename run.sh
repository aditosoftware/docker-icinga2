#!/bin/bash


#Change permissions icingaweb2 and icinga2 custom configuration folder
service mysql stop
chmod 777 /icingaweb2/* -R
chmod 777 /icinga2conf/* -R
chmod 777 /mysql
service mysql start

#Check env
if [ -z "$ICINGA_PASS" ]; then
	export ICINGA_PASS="icinga"
	echo "Set icingaadmin pass to icinga"
else
	echo $ICINGA_PASS
fi
if [ -z "GRAPHITE_HOST" ]; then
	echo "Graphite Host not defined.Exit"
	exit
else
	echo $GRAPHITE_HOST
fi
if [ -z "MAILSERVER" ]; then
	echo "Mailserver not defined"
else
	#Add email forwarding to $MAILSERVER
	echo "*       smtp:'$MAILSERVER'" > /etc/postfix/transport
	postmap /etc/postfix/transport
fi
if [ -z "$EMAILADDR" ]; then
	echo "Email for icingaadmin not defined"
else
	sed -i 's/'"root@localhost"'/'"$EMAILADDR"'/' /etc/icinga2/conf.d/users.conf
fi
if [[ ! -e /icinga2conf/externalcommands ]]; then
    mkdir /icinga2conf/externalcommands
fi
if [[ -e /mysql ]]; then
	service mysql stop
	cp -R /var/lib/mysql/* /mysql/
	sed -i "s#datadir.*#datadir = /mysql#g" /etc/mysql/my.cnf
else
	service mysql stop
	sed -i "s#datadir.*#datadir = /mysql#g" /etc/mysql/my.cnf
fi
if [ -z "$NSCAPASS" ]; then
	echo "nsca password not defined"
else
	echo "password=$NSCAPASS" >> /etc/nsca.cfg
fi
if [ -z "$NSCAPORT" ]; then
	echo "nsca port not defined"
else
	sed -i "s/server_port.*/server_port=$NSCAPORT/g" /etc/nsca.cfg
fi
if [ $ENABLE_AD_AUTH -eq "1" ]; then
	#Add AD Auth (resources.ini)
	if [[ -e /icingaweb2 ]]; then
		if [[ -s /icingaweb2/resources.ini ]]; then
			rm /etc/icingaweb2/resources.ini
			ln -s /icingaweb2/resources.ini /etc/icingaweb2/resources.ini
		else
			cp /etc/icingaweb2/resources.ini /icingaweb2/resources.ini
			echo "[ad]" >> /icingaweb2/resources.ini
			echo " type            = \"ldap\"" >> /icingaweb2/resources.ini
			echo "hostname        = \"$AD_NAME\"" >> /icingaweb2/resources.ini
			echo "port            = \"389\" " >> /icingaweb2/resources.ini
			echo "root_dn         = \"$AD_ROOT_DN\"" >> /icingaweb2/resources.ini
			echo "bind_dn         = \"$AD_BIND_DN\"" >> /icingaweb2/resources.ini
			echo "bind_pw         = \"$AD_BIND_PW\"" >> /icingaweb2/resources.ini
			rm /etc/icingaweb2/resources.ini
			ln -s /icingaweb2/resources.ini /etc/icingaweb2/resources.ini
		fi
		if [[ -s /icingaweb2/authentication.ini ]]; then
			rm /etc/icingaweb2/authentication.ini
			ln -s /icingaweb2/authentication.ini /etc/icingaweb2/authentication.ini
		else
			#Add authentication.ini
			cp /etc/icingaweb2/authentication.ini /icingaweb2/authentication.ini
			echo "[AD]" >> /icingaweb2/authentication.ini
			echo "resource = \"ad\" " >> /icingaweb2/authentication.ini
			echo "backend = \"msldap\" " >> /icingaweb2/authentication.ini
			rm /etc/icingaweb2/authentication.ini
			ln -s /icingaweb2/authentication.ini /etc/icingaweb2/authentication.ini
		fi
		if [[ -s /icingaweb2/roles.ini ]]; then
			rm /etc/icingaweb2/roles.ini
			ln -s /icingaweb2/roles.ini /etc/icingaweb2/roles.ini
		else
			#Add authentication.ini
			cp /etc/icingaweb2/roles.ini /icingaweb2/roles.ini
			rm /etc/icingaweb2/roles.ini
			ln -s /icingaweb2/roles.ini /etc/icingaweb2/roles.ini
		fi
		
	else
		echo "[ad]" >> /etc/icingaweb2/resources.ini
		echo " type            = \"ldap\"" >> /etc/icingaweb2/resources.ini
		echo "hostname        = \"$AD_NAME\"" >> /etc/icingaweb2/resources.ini
		echo "port            = \"389\" " >> /etc/icingaweb2/resources.ini
		echo "root_dn         = \"$AD_ROOT_DN\"" >> /etc/icingaweb2/resources.ini
		echo "bind_dn         = \"$AD_BIND_DN\"" >> /etc/icingaweb2/resources.ini
		echo "bind_pw         = \"$AD_BIND_PW\"" >> /etc/icingaweb2/resources.ini

		#Add authentication.ini
		echo "[AD]" >> /etc/icingaweb2/resources.ini
		echo "resource = \"ad\" " >> /etc/icingaweb2/authentication.ini
		echo "backend = \"msldap\" " >> /etc/icingaweb2/authentication.ini
	fi
else
	if [[ -s /icingaweb2/resources.ini ]]; then
			rm /etc/icingaweb2/resources.ini
			ln -s /icingaweb2/resources.ini /etc/icingaweb2/resources.ini
	fi
	if [[ -s /icingaweb2/authentication.ini ]]; then
			rm /etc/icingaweb2/authentication.ini
			ln -s /icingaweb2/authentication.ini /etc/icingaweb2/authentication.ini
	fi
	if [[ -s /icingaweb2/roles.ini ]]; then
			rm /etc/icingaweb2/roles.ini
			ln -s /icingaweb2/roles.ini /etc/icingaweb2/roles.ini
	fi
	if [[ -s /icingaweb2/groups.ini ]]; then
		rm /etc/icingaweb2/groups.ini
		ln -s /icingaweb2/groups.ini /etc/icingaweb2/groups.ini
	fi
fi


htpasswd -b /etc/icinga2-classicui/htpasswd.users icingaadmin $ICINGA_PASS
pass=$(openssl passwd -1 $ICINGA_PASS)

service mysql restart

#Change Icinga user password
echo "update icingaweb_user set password_hash='$pass' where name='icingaadmin';" >> ~/usergen.sql
mysql -u root -proot icingaweb < ~/usergen.sql
rm -f ~/usergen.sql
chown mysql:mysql -R /mysql

#Change Graphite host
sed -i "3s#base.*#base_url=http://$GRAPHITE_HOST/render?#" /etc/icingaweb2/modules/graphite/config.ini

#Change postfix hostname
sed -i "s/myhostname.*/myhostname=$HOSTNAME/g" /etc/postfix/main.cf

#Change permissions icingaweb2 and icinga2 custom configuration folder
chmod 777 /icingaweb2/* -R
chmod 777 /icinga2conf/* -R
chmod 777 /mysql



#Restart service
service apache2 restart
service icinga2 restart
service carbon-cache restart
service postfix restart
service nsca stop

exec nsca -c /etc/nsca.cfg -f --daemon
