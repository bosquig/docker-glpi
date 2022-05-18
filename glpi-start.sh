#!/bin/bash

#Controle du choix de version ou prise de la latest
[[ ! "$VERSION_GLPI" ]] \
	&& VERSION_GLPI=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4)

if [[ -z "${TIMEZONE}" ]]; then echo "TIMEZONE is unset"; 
else 
echo "date.timezone = \"$TIMEZONE\"" > /etc/php/7.3/apache2/conf.d/timezone.ini;
echo "date.timezone = \"$TIMEZONE\"" > /etc/php/7.3/cli/conf.d/timezone.ini;
fi

SRC_GLPI=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/tags/${VERSION_GLPI} | jq .assets[0].browser_download_url | tr -d \")
TAR_GLPI=$(basename ${SRC_GLPI})
FOLDER_GLPI=glpi/
FOLDER_WEB=/var/www/html/

#check if TLS_REQCERT is present
if !(grep -q "TLS_REQCERT" /etc/ldap/ldap.conf)
then
	echo "TLS_REQCERT isn't present"
        echo -e "TLS_REQCERT\tnever" >> /etc/ldap/ldap.conf
fi

#Téléchargement et extraction des sources de GLPI
if [ "$(ls ${FOLDER_WEB}${FOLDER_GLPI})" ];
then
	echo "GLPI is already installed"
else
	wget -P ${FOLDER_WEB} ${SRC_GLPI}
	tar -xzf ${FOLDER_WEB}${TAR_GLPI} -C ${FOLDER_WEB}
	rm -Rf ${FOLDER_WEB}${TAR_GLPI}
	if [[ "$VERSION_GLPI" < "9.5.0" ]]; then
		echo "Inferieur a 9.5"
		cp /opt/dbmysql.class.php ${FOLDER_WEB}${FOLDER_GLPI}inc
	fi
	chown -R www-data:www-data ${FOLDER_WEB}${FOLDER_GLPI}
fi
rm -Rf ${FOLDER_WEB}${FOLDER_GLPI}files
ln -s /mnt/files/ ${FOLDER_WEB}${FOLDER_GLPI}
cp -r /mnt/plugins/ ${FOLDER_WEB}${FOLDER_GLPI}
chown -R www-data:www-data ${FOLDER_WEB}${FOLDER_GLPI}plugins
chmod -R 777 ${FOLDER_WEB}${FOLDER_GLPI}plugins


if [[ ! "$INSTALL" ]]; 
	then
	rm -Rf ${FOLDER_WEB}${FOLDER_GLPI}install
fi


echo "Start sshd"
/usr/sbin/sshd
service ssh start
if [[ "$DBSSL" == "True" ]]; then
	echo "<?php class DB extends DBmysql {                public \$dbhost     = '$MARIAHOST';                public \$dbuser     = '$MARIAUSER';                 public \$dbpassword = '$MARIAPASSWORD';                 public \$dbdefault  = '$MARIADB';   public \$dbssl = true;    public \$dbsslca = '/etc/ssl/ca-cert.pem';             }" > /var/www/html/glpi/config/config_db.php
else
	echo "<?php class DB extends DBmysql {                public \$dbhost     = '$MARIAHOST';                public \$dbuser     = '$MARIAUSER';                 public \$dbpassword = '$MARIAPASSWORD';                 public \$dbdefault  = '$MARIADB';   public \$dbssl = false;              }" > /var/www/html/glpi/config/config_db.php
fi
sed -i 's/GLPI_VAR_DIR \. "\/_sessions"/GLPI_ROOT \. "\/sessions"/g' /var/www/html/glpi/inc/based_config.php
sed -i 's/{GLPI_VAR_DIR}\/_sessions/{GLPI_ROOT}\/sessions/g' /var/www/html/glpi/inc/based_config.php


mkdir ${FOLDER_WEB}${FOLDER_GLPI}sessions
chown -R www-data:www-data ${FOLDER_WEB}${FOLDER_GLPI}sessions
chmod 777 -R ${FOLDER_WEB}${FOLDER_GLPI}sessions
cp /opt/.htaccess ${FOLDER_WEB}${FOLDER_GLPI}files/.htaccess
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_cache
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_cron
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_dumps
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_graphs
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_lock
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_pictures
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_plugins
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_rss
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_tmp
mkdir -p ${FOLDER_WEB}${FOLDER_GLPI}files/_uploads
#Modification du vhost par défaut
echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

#Add scheduled task by cron and enable
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi
#Start cron service
service cron start
#Activation du module rewrite d'apache
a2enmod rewrite && service apache2 restart && service apache2 stop

#Lancement du service apache au premier plan
/usr/sbin/apache2ctl -D FOREGROUND
