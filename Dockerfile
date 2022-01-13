#On choisit une debian
FROM debian:10.4

MAINTAINER DiouxX "github@diouxx.be"

#Ne pas poser de question à l'installation
ENV DEBIAN_FRONTEND noninteractive

#Installation d'apache et de php7.3 avec extension
RUN apt update \
&& apt install --yes --no-install-recommends \
apache2 \
php7.3 \
php7.3-mysql \
php7.3-ldap \
php7.3-xmlrpc \
php7.3-imap \
curl \
php7.3-curl \
php7.3-gd \
php7.3-mbstring \
php7.3-xml \
php7.3-apcu-bc \
php-cas \
php7.3-intl \
php7.3-zip \
php7.3-bz2 \
cron \
openssh-server \
ssh \
sudo \
cifs-utils \
wget \
ca-certificates \
jq \
&& echo "root:Docker!" | chpasswd \
&& rm -rf /var/lib/apt/lists/*

# Copy the sshd_config file to the /etc/ssh/ directory
COPY sshd_config /etc/ssh/

# Copy and configure the ssh_setup file
RUN mkdir -p /tmp
RUN mkdir -p /mnt/glpi
RUN chmod 777 -R /mnt/glpi
COPY ssh_setup.sh /tmp
RUN chmod +x /tmp/ssh_setup.sh \
    && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null)

RUN service ssh start

#Copie et execution du script pour l'installation et l'initialisation de GLPI
COPY glpi-start.sh /opt/
COPY config.php /opt/
COPY define.php /opt/
RUN chmod +x /opt/glpi-start.sh
ENTRYPOINT ["/opt/glpi-start.sh"]

#Exposition des ports
EXPOSE 80 443 2222 445
