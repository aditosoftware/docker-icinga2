# Description

This is a Docker container with Icinga2 (Icingaweb2 and Icinag2-Classicui), Graphite and Graphite Modul for Icingaweb2

## Variables

  Enable Active Directory Auth. You need the folder "/icingaweb2" in container.

    ENABLE_AD_AUTH=1
  
  Active Directory name or name of a domain controller
  
    AD_NAME=example.com
  
  AD OU for Icingaweb2 Auth Users:
    
    AD_ROOT_DN=OU=accounts,OU=intern,DC=example,DC=com
  
  Path for User (only to list ad users)
    
    AD_BIND_DN=CN=aduser,OU=management,OU=accounts,OU=intern,DC=excample,DC=com
  
  Password for user
  
    AD_BIND_PW=PASSWORDHERE
  
  Graphite host with port. Graphite is installed in container you need here the ip from Docker container and port
  
    GRAPHITE_HOST=192.168.100.203:80
  
  Icinga2 password for "icingaadmin"
  
    ICINGA_PASS=icinga
  
  Mailserver for Email notifications. 
  
    MAILSERVER=mail.example.com
  
  Email address for icingaadmin user
  
    EMAILADDR=user@example.com
  
  NSCA (passive checks) is enabled. Password
    
    NSCAPASS=pass
  
  NSCA Port
    
    NSCAPORT=5667
    
  !Define host name
  
    docker run -h "hostname"
    
## Example
  
    sudo docker run -i -p 80:80 -p 5667:5667 -h monitoring.example.com \
    -v /storage/icingaweb2:/icingaweb2 -v /storage/icinga2:/icinga2conf -v /storage/mysql:/mysql \
    -e ENABLE_AD_AUTH="1" -e AD_NAME="example.com" -e AD_ROOT_DN="OU=accounts,OU=intern,DC=example,DC=com" \
    -e AD_BIND_DN="CN=Icinga2 Auth,OU=accounts,OU=intern,DC=example,DC=com" -e AD_BIND_PW="PASSWORDHERE" \
    -e GRAPHITE_HOST=192.168.100.61:80 -e ICINGA_PASS="icinga" -e MAILSERVER="mail.example.com" \
    -e EMAILADDR="user@example.com" -e NSCAPASS="pass" -e NSCAPORT="5667" \
    --name icinga2 -t adito/icinga2
