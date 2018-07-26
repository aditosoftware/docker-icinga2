# Description

This is a Docker container with Icinga2 (Icingaweb2 and Icinag2-Classicui). 

### Update

1. Update to icinga2 v2.9.1-1 and icingaweb2 2.6.0 
2. Now with Ubutu 18.04 
3. Add supervisor service 
4. Removed graphite from container, you need now a separated container with graphite 

### Ports

Icinga2 running on port **80** (redirect to host/icingaweb2) 
Icinga2 API on port **5665** (don't forgot to set user and password) 
Icinga2 NSCA on port **5667** (for receive passive checks) 

## Variables

  Enable Active Directory Auth. You need the folder "/icingaweb2" in container.

    ENABLE_AD_AUTH=1 (optional)
  
  Active Directory name or name of a domain controller
  
    AD_NAME=example.com (optional)
  
  AD OU for Icingaweb2 Auth Users:
    
    AD_ROOT_DN=OU=accounts,OU=intern,DC=example,DC=com (optional)
  
  Path for User (only to list ad users)
    
    AD_BIND_DN=CN=aduser,OU=management,OU=accounts,OU=intern,DC=excample,DC=com (optional)
  
  Password for user
  
    AD_BIND_PW=PASSWORDHERE (optional)
  
  Enable Graphite

    ENABLEGRAPHITE=true/TRUE/0

  Graphite transport port

    GRAPHITE_TRANS=http or https

  Graphite host
    
    GRAPHITE_WEBHOST=192.168.100.203
  
  Graphite port for website

    GRAPHITE_WEBSITE_PORT = 

  Graphite user

    GRAPHITE_USER=

  Graphite pass

    GRAPHITE_PASS=

  Graphite security, this option will be need for icinga2 to send the data, it's meen ssl or not

    GRAPHITE_SECUR = 0/1

  Graphite port for file /etc/icinga2/feature-available/graphite.conf

    GRAPHITE_HOST

  Graphite host (default 2003), but you need to define this

    GRAPHITE_PORT = 2003
  
  Notification Periode (0 for disable, default 30Min)(optional). If set to 0, Icinga will send notificaton only if status of service is changed.
  
    NOTIFICATION_INTERVAL=0
  
  Icinga2 password for "icingaadmin"
  
    ICINGA_PASS=icinga
  
  Mailserver for Email notifications. I use the tool "mailx" (heirloom-mailx) and my exchange server (email redirect from monitoring server ip is allow).  
  
    MAILSERVER=mail.example.com (optional)
  
  Email address for icingaadmin user
  
    EMAILADDR=user@example.com (optional)
  
  NSCA (passive checks) is enabled. Password here
    
    NSCAPASS=pass (optional)
  
  NSCA Port
    
    NSCAPORT=5667 (optional)
    
  Enable API, if var APIUSER defined. Access: https://monitoring.server.com:5665
  
    APIUSER=apiuser (optional)
    
  Password for api user. If not defined set default to "icingaapi2012m"
    
    APIPASS=apipass

  Remove monitoring service "swap" of the monitoring server self, for example if this container running in k8s (the swap is not enabled in kubernetes cluster)

    SWAPSERVICEOFF=true

  Remove monitoring service "disk" of the monitoring server self

    DISCSERVICEOFF=true
  
  Remove default services (serices.conf)

    REMOVEDEFAULTSVC = true/TRUE/1
  
  !Define host name
  
    docker run -h "hostname"
    
  For time sync
    
    -v /etc/localtime:/etc/localtime:ro
    
### Folder  

    - /icingaweb2
    - /icinga2conf
    - /mysql
    - /var/lib/graphite/whisper
       
    
## Example
  
    sudo docker run -d -p 80:80 -p 5667:5667 -p 5665:5665 -p 8080:8080 -h monitoring.example.com \
    -v /storage/icingaweb2:/icingaweb2 -v /storage/icinga2:/icinga2conf -v /storage/mysql:/mysql \
    -e ENABLE_AD_AUTH="1" -e AD_NAME="example.com" -e AD_ROOT_DN="OU=accounts,OU=intern,DC=example,DC=com" \
    -e AD_BIND_DN="CN=Icinga2 Auth,OU=accounts,OU=intern,DC=example,DC=com" -e AD_BIND_PW="PASSWORDHERE" \
    -e NOTIFICATION_INTERVAL=0 ENABLEGRAPHITE=true -e GRAPHITE_TRANS=http -e GRAPHITE_HOST=192.168.42.59 -e GRAPHITE_WEBSITE_PORT=8081 -e GRAPHITE_USER=guest -e GRAPHITE_PASS=guest -e GRAPHITE_SECUR=0 -e GRAPHITE_PORT=2003 -e ICINGA_PASS="icinga" -e MAILSERVER="mail.example.com" \
    -e EMAILADDR="user@example.com" -e NSCAPASS="pass" -e NSCAPORT="5667" -e APIUSER=root -e APIPASS=pass \
    --name icinga2 -t adito/icinga2

## Example 2 (without AD)

    sudo docker run -i -p 80:80 -p 5667:5667 -p 5665:5665 -p 8080:8080 -h monitoring.example.com \
    -v /storage/icingaweb2:/icingaweb2 -v /storage/icinga2:/icinga2conf -v /storage/mysql:/mysql \
    -v /storage/graphite:/var/lib/graphite/whisper \
    -e NOTIFICATION_INTERVAL=0 ENABLEGRAPHITE=true -e GRAPHITE_TRANS=http -e GRAPHITE_HOST=192.168.42.59 -e GRAPHITE_WEBSITE_PORT=8081 -e GRAPHITE_USER=guest -e GRAPHITE_PASS=guest -e GRAPHITE_SECUR=0 -e GRAPHITE_PORT=2003 \
    -e APIUSER=root -e APIPASS=PASS -e ICINGA_PASS="icinga" \
    -e MAILSERVER="mail.example.com" -e EMAILADDR="user@example.com" -e NSCAPASS="pass" -e NSCAPORT="5667" \
    --name icinga2 -t adito/icinga2

## Example 3 (without AD and running in k8s cluster (disable swap and disk service))

    sudo docker run -i -p 80:80 -p 5667:5667 -p 5665:5665 -p 8080:8080 -h monitoring.example.com \
    -v /storage/icingaweb2:/icingaweb2 -v /storage/icinga2:/icinga2conf -v /storage/mysql:/mysql \
    -v /storage/graphite:/var/lib/graphite/whisper \
    -e NOTIFICATION_INTERVAL=0 ENABLEGRAPHITE=true \
    -e GRAPHITE_TRANS=http -e GRAPHITE_HOST=192.168.42.59 \
    -e GRAPHITE_WEBSITE_PORT=8081 -e GRAPHITE_USER=guest \
    -e GRAPHITE_PASS=guest -e GRAPHITE_SECUR=0 -e GRAPHITE_PORT=2003 \
    -e APIUSER=root -e APIPASS=PASS -e ICINGA_PASS="icinga" \
    -e SWAPSERVICEOFF=true -e DISCSERVICEOFF=true \
    -e MAILSERVER="mail.example.com" -e EMAILADDR="user@example.com" -e NSCAPASS="pass" -e NSCAPORT="5667" \
    --name icinga2 -t adito/icinga2