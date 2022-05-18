#On choisit une debian
FROM debian:10.4

MAINTAINER DiouxX "github@diouxx.be"

#Ne pas poser de question à l'installation
ENV DEBIAN_FRONTEND noninteractive

#Installation d'apache et de php7.4 avec extension
RUN apt update \
&& apt -y upgrade && apt update && apt install -y wget lsb-release apt-transport-https software-properties-common gnupg2 && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list && wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add - && apt update && apt install --yes --no-install-recommends \
php7.4 \
php7.4-mysql \
php7.4-ldap \
php7.4-xmlrpc \
php7.4-imap \
php7.4-curl \
php7.4-gd \
php7.4-mbstring \
php7.4-xml \
php7.4-apcu-bc \
php7.4-intl \
php7.4-zip \
php7.4-bz2 \
php-cas \
apache2 \
curl \
nano \
cron \
openssh-server \
ssh \
sudo \
cifs-utils \
ca-certificates \
jq \
&& echo "root:Docker!" | chpasswd \
&& rm -rf /var/lib/apt/lists/*

# Copy the sshd_config file to the /etc/ssh/ directory
COPY sshd_config /etc/ssh/
COPY ca-cert.pem /etc/ssl/
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
COPY dbmysql.class.php /opt/
COPY config.php /opt/
COPY define.php /opt/
COPY .htaccess /opt/
RUN chmod +x /opt/glpi-start.sh
ENTRYPOINT ["/opt/glpi-start.sh"]

#Exposition des ports
EXPOSE 80 443 2222 445
