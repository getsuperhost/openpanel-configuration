#!/bin/sh

#Remove all ftp users
grep '/ftp/' /etc/passwd | cut -d':' -f1 | xargs -r -n1 deluser

#Create users
#USERS='name1|password1|folder1|GROUP_ID name2|password2||folder2|GROUP_ID '


if [ -z "$USERS" ]; then
  USERS="alpineftp|alpineftp"
fi

for i in $USERS ; do
  NAME=$(echo $i | cut -d'|' -f1)
  OPENPANEL_USER=$(echo $NAME | rev | cut -d'.' -f1 | rev)
  GROUP=$OPENPANEL_USER
  PASS=$(echo $i | cut -d'|' -f2)
  FOLDER=$(echo $i | cut -d'|' -f3)
  GID=$(echo $i | cut -d'|' -f4)

  if [ -z "$FOLDER" ]; then
    FOLDER="/ftp/$NAME"
  fi

    if [ -z "$GID" ]; then
      GID="33" # www-data group
    fi
    
    #Check if the group with the same ID already exists
    GROUP=$(getent group $GID | cut -d: -f1)
    if [ ! -z "$GROUP" ]; then
      GROUP_OPT="-G $GROUP"
    elif [ ! -z "$GID" ]; then
      # Group don't exist but GID supplied
      addgroup -g $GID $OPENPANEL_USER
      GROUP_OPT="-G $OPENPANEL_USER"

      # https://serverfault.com/a/435430/1254613
      chmod +rx /home/$OPENPANEL_USER
      chmod +rx /home/$OPENPANEL_USER/docker-data
      chmod +rx /home/$OPENPANEL_USER/docker-data/volumes
      chmod +rx /home/$OPENPANEL_USER/docker-data/volumes/${OPENPANEL_USER}_html_data
      chmod +rx /home/$OPENPANEL_USER/docker-data/volumes/${OPENPANEL_USER}_html_data/_data     
    fi

  echo -e "$PASS\n$PASS" | adduser -h $FOLDER -s /sbin/nologin $GROUP_OPT $NAME
  unset NAME PASS FOLDER UID GID
done


if [ -z "$MIN_PORT" ]; then
  MIN_PORT=21000
fi

if [ -z "$MAX_PORT" ]; then
  MAX_PORT=21010
fi

if [ ! -z "$ADDRESS" ]; then
  ADDR_OPT="-opasv_address=$ADDRESS"
fi

if [ ! -z "$TLS_CERT" ] || [ ! -z "$TLS_KEY" ]; then
  TLS_OPT="-orsa_cert_file=$TLS_CERT -orsa_private_key_file=$TLS_KEY -ossl_enable=YES -oallow_anon_ssl=NO -oforce_local_data_ssl=YES -oforce_local_logins_ssl=YES -ossl_tlsv1=NO -ossl_sslv2=NO -ossl_sslv3=NO -ossl_ciphers=HIGH"
fi

# Used to run custom commands inside container
if [ ! -z "$1" ]; then
  exec "$@"
else
  vsftpd -opasv_min_port=$MIN_PORT -opasv_max_port=$MAX_PORT $ADDR_OPT $TLS_OPT /etc/vsftpd/vsftpd.conf
  [ -d /var/run/vsftpd ] || mkdir /var/run/vsftpd
  pgrep vsftpd | tail -n 1 > /var/run/vsftpd/vsftpd.pid
  exec pidproxy /var/run/vsftpd/vsftpd.pid true
fi
