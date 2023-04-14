FROM ubuntu:jammy
MAINTAINER Wildan M <willnode@wellosoft.net>

WORKDIR /root
ARG DEBIAN_FRONTEND=noninteractive

# Repositories (204 MB apt install)
RUN sed -i 's#exit 101#exit 0#' /usr/sbin/policy-rc.d && \
    rm /etc/apt/apt.conf.d/docker-gzip-indexes && \
    apt-get update && apt-get install software-properties-common \
    apt-transport-https ca-certificates perl wget curl -y && \ 
    apt-get clean && apt-get update

# Virtualmin Repos
COPY ./scripts/install.sh ./scripts/slib.sh /root/
RUN chmod +x *.sh && TERM=xterm-256color COLUMNS=100 ./install.sh --force --setup

# Webmin (38.6 MB + 111 MB + 224 MB)
RUN apt-get install -y webmin && \
    apt-get install -y nginx-common && \
    sed -i 's/listen \[::\]:80 default_server;/#listen \[::\]:80 default_server;/' /etc/nginx/sites-available/default && \
    apt-get install -y virtualmin-lemp-stack-minimal virtualmin-core usermin perl-modules --no-install-recommends

# Terminal tools (442 MB)
RUN apt-get install -y git mercurial nano vim procps ntpdate \
    iproute2 net-tools openssl whois screen autoconf automake \
    dirmngr gnupg gpg make libtool zip unzip tar sqlite3 \
    python3 e2fsprogs dnsutils sudo nodejs ncdu htop iftop \
    php-pear php php-common php-cli php-cgi php-fpm \ 
    build-essential zlib1g-dev libssl-dev libreadline-dev \
    --no-install-recommends

# SystemD replacement
COPY ./scripts/systemctl3.py /root/
RUN cp -f systemctl3.py /usr/bin/systemctl

# Services (384 MB)
RUN apt-get install -y postgresql postgresql-contrib \
    openssh-server mariadb-server mariadb-client \
    bind9 bind9-host cron libdbd-pg-perl

# Make sure all services installed
RUN systemctl enable mariadb && \
    systemctl enable postgresql && \
    systemctl enable nginx && \
    systemctl enable cron && \
    systemctl enable ssh && \
    systemctl enable php8.1-fpm && \
    systemctl enable named && \
    systemctl enable webmin

# Passenger Nginx (88.9 MB)
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 && \
    echo deb https://oss-binaries.phusionpassenger.com/apt/passenger jammy main > /etc/apt/sources.list.d/passenger.list && \
    apt-get update && apt-get install -y libnginx-mod-http-passenger

# Misc
RUN ssh-keygen -A && \
    sed -i "s@#Port 22@Port 2122@" /etc/ssh/sshd_config && \
    git config --global pull.rebase false && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    chown -R mysql:mysql /var/lib/mysql && \
    mkdir -p /run/php && chmod 777 /run/php


# resolv.conf can't be overriden inside docker
COPY ./scripts/setup/ /root/setup/
RUN cp -a ./setup/* /usr/share/perl5/Virtualmin/Config/Plugin/ && \
    virtualmin config-system -b MiniLEMP -i PostgreSQL

# set webmin port & root password
ARG WEBMIN_ROOT_PASSWORD
ARG WEBMIN_ROOT_PORT_PREFIX
RUN sed -i "s@port=10000@port=${WEBMIN_ROOT_PORT_PREFIX}0@" /etc/webmin/miniserv.conf && \
    /usr/share/webmin/changepass.pl /etc/webmin root ${WEBMIN_ROOT_PASSWORD}

# save mount artifacts
COPY ./scripts/save.sh ./scripts/start.sh /root/
COPY ./templates/ /tmp/artifacts/templates/
RUN cp -f /tmp/artifacts/templates/nginx.conf /etc/nginx/nginx.conf
RUN chmod +x *.sh && ./save.sh

ENTRYPOINT sh /root/start.sh
