FROM ubuntu:latest
MAINTAINER Wildan M <willnode@wellosoft.net>

WORKDIR /root
ARG DEBIAN_FRONTEND=noninteractive

RUN sed -i 's#exit 101#exit 0#' /usr/sbin/policy-rc.d
RUN rm  /etc/apt/apt.conf.d/docker-gzip-indexes \
    &&  apt-get -o Acquire::GzipIndexes=false update -y \
    &&  apt-get upgrade -y

# GNU tools
RUN apt-get install -y curl git nano vim wget procps \
    iproute2 net-tools openssl whois screen \
    gcc g++ dirmngr gnupg gpg make cmake apt-utils \
    perl golang-go rustc cargo rake ruby zip unzip tar \
    python3 e2fsprogs dnsutils quota linux-image-extra-virtual rsyslog \
    libcrypt-ssleay-perl software-properties-common language-pack-en

# SystemD replacement
COPY ./scripts/systemctl3.py /root/
RUN cp -f systemctl3.py /usr/bin/systemctl

# Services
RUN apt-get install -y postgresql postgresql-contrib \
    openssh-server mariadb-server mariadb-client \
    bind9 bind9-host fail2ban nginx

# PHP
RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y && \
	add-apt-repository ppa:adiscon/v8-stable -y && \
    apt-get update && apt-get upgrade -y
RUN apt-get install -y composer php-pear php5.6 php5.6-cgi php5.6-cli php5.6-fpm \
    php5.6-curl php5.6-imap php5.6-gd php5.6-mysql php5.6-pgsql php5.6-sqlite3 \
    php5.6-mbstring php5.6-json php5.6-bz2 php5.6-mcrypt php5.6-xmlrpc php5.6-gmp \
    php5.6-xsl php5.6-soap php5.6-xml php5.6-zip php5.6-dba \
    php7.4 php7.4-cgi php7.4-cli php7.4-fpm php7.4-sqlite3 \
    php7.4-json php7.4-mysql php7.4-curl php7.4-ctype php7.4-uuid \
    php7.4-iconv php7.4-mbstring php7.4-gd php7.4-intl php7.4-xml \
    php7.4-zip php7.4-gettext php7.4-pgsql php7.4-bcmath php7.4-redis \
    php7.4-readline php7.4-soap php7.4-igbinary php7.4-msgpack \
    php8.1 php8.1-cgi php8.1-cli php8.1-fpm php8.1-curl php8.1-ctype \
    php8.1-uuid php8.1-pgsql php8.1-sqlite3 php8.1-gd php8.1-redis \
    php8.1-imap php8.1-mysql php8.1-mbstring php8.1-iconv php8.1-grpc \
    php8.1-xml php8.1-zip php8.1-bcmath php8.1-soap php8.1-gettext \
    php8.1-intl php8.1-readline php8.1-msgpack php8.1-igbinary php8.1-ldap

# Virtualmin
COPY ./scripts/install.sh ./scripts/slib.sh /root/
RUN ./install.sh --minimal --force --verbose --bundle LEMP

# Nodejs & C++
RUN curl --fail -sSL -o setup-nodejs https://deb.nodesource.com/setup_16.x && \
    bash setup-nodejs && \
    apt-get install -y nodejs

# Passenger Nginx
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 && \
    apt-get install -y apt-transport-https ca-certificates && \
    echo deb https://oss-binaries.phusionpassenger.com/apt/passenger focal main > /etc/apt/sources.list.d/passenger.list && \
    apt-get update && apt-get install -y libnginx-mod-http-passenger

ARG WEBMIN_ROOT_PORT_PREFIX
ARG WEBMIN_ROOT_HOSTNAME

# Misc
RUN ssh-keygen -A && \
    npm install -g yarn pnpm && \
    sed -i "s@#Port 22@Port 2122@" /etc/ssh/sshd_config && \
    git config --global pull.rebase false && \
    cp -f systemctl3.py /usr/bin/systemctl && \
    sed -i "s@port=10000@port=${WEBMIN_ROOT_PORT_PREFIX}0@" /etc/webmin/miniserv.conf

# resolv.conf can't be overriden inside docker
COPY ./scripts/Net.pm ./scripts/ProFTPd.pm ./scripts/SASL.pm ./
RUN cp -t /usr/share/perl5/Virtualmin/Config/Plugin/ Net.pm ProFTPd.pm SASL.pm  && \
    virtualmin config-system -b MiniLEMP

# Firewall
RUN systemctl disable firewalld && \
    systemctl mask --now firewalld && \
    systemctl disable clamav-freshclam && \
    systemctl disable proftpd && \
    systemctl disable saslauthd && \
    systemctl disable dovecot && \
    systemctl enable mysql && \
    systemctl enable postgresql && \
    systemctl enable nginx && \
    systemctl enable webmin && \
    systemctl enable sshd && \
    systemctl enable php5.6-fpm && \
    systemctl enable php7.4-fpm && \
    systemctl enable php8.1-fpm && \

# Temporary fix for nginx
# RUN yum downgrade wbm-virtualmin-nginx-2.21 -y && \
#     yum downgrade wbm-virtualmin-nginx-ssl-1.15 -y

# set root password
ARG WEBMIN_ROOT_PASSWORD
RUN /usr/share/webmin/changepass.pl /etc/webmin root ${WEBMIN_ROOT_PASSWORD}

# save mount artifacts
COPY ./scripts/save.sh ./scripts/start.sh  /root/
RUN chmod +x /root/* && ./save.sh

ENTRYPOINT /root/start.sh
