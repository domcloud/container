FROM ubuntu:latest
MAINTAINER Wildan M <willnode@wellosoft.net>

WORKDIR /root
ARG DEBIAN_FRONTEND=noninteractive

# Repositories
RUN sed -i 's#exit 101#exit 0#' /usr/sbin/policy-rc.d
RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes && \
    apt-get update && apt-get install software-properties-common \
    apt-transport-https ca-certificates perl wget curl -y && \
    add-apt-repository ppa:longsleep/golang-backports -y && \
    LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y && \
    add-apt-repository ppa:adiscon/v8-stable -y && \
    apt-get clean && apt-get update

# Virtualmin Repos
COPY ./scripts/install.sh ./scripts/slib.sh /root/
RUN chmod +x *.sh && TERM=xterm-256color COLUMNS=100 ./install.sh --force --setup

# Webmin
RUN apt-get install -y webmin && \
    apt-get install -y nginx-common && \
    sed -i 's/listen \[::\]:80 default_server;/#listen \[::\]:80 default_server;/' /etc/nginx/sites-available/default && \
    apt-get install -y virtualmin-lemp-stack-minimal --no-install-recommends && \
    apt-get install -y virtualmin-core

# Terminal tools
RUN apt-get install -y git mercurial nano vim procps ntpdate \
    iproute2 net-tools openssl whois screen autoconf automake \
    gcc g++ dirmngr gnupg gpg make cmake apt-utils libtool \
    golang-go rustc cargo rake ruby zip unzip tar sqlite3 \
    python3 e2fsprogs dnsutils quota sudo rsyslog language-pack-en

# PHP
RUN apt-get install -y php-pear php8.1 php8.1-common php8.1-cli php8.1-cgi php8.1-fpm && \
    update-alternatives --set php /usr/bin/php8.1

# PHP extensions
RUN apt-get install -y php8.1-curl php8.1-ctype php8.1-uuid php8.1-pgsql \
    php8.1-sqlite3 php8.1-gd php8.1-redis php8.1-ldap \
    php8.1-mysql php8.1-mbstring php8.1-iconv php8.1-grpc \
    php8.1-xml php8.1-zip php8.1-bcmath php8.1-soap php8.1-gettext \
    php8.1-intl php8.1-readline php8.1-msgpack php8.1-igbinary

# Nodejs
RUN curl --fail -sSL -o setup-nodejs https://deb.nodesource.com/setup_16.x && \
    bash setup-nodejs && apt-get install -y nodejs

# SystemD replacement
COPY ./scripts/systemctl3.py /root/
RUN cp -f systemctl3.py /usr/bin/systemctl

# Services
RUN apt-get install -y postgresql postgresql-contrib \
    openssh-server mariadb-server mariadb-client \
    bind9 bind9-host proftpd

# Make sure all services installed
RUN systemctl enable mariadb && \
    systemctl enable postgresql && \
    systemctl enable nginx && \
    systemctl enable ssh && \
    systemctl enable php8.1-fpm && \
    systemctl enable named && \
    systemctl enable webmin

# Passenger Nginx
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 && \
    echo deb https://oss-binaries.phusionpassenger.com/apt/passenger focal main > /etc/apt/sources.list.d/passenger.list && \
    apt-get update && apt-get install -y libnginx-mod-http-passenger

# Misc
RUN ssh-keygen -A && \
    npm install -g npm@latest yarn pnpm && \
    sed -i "s@#Port 22@Port 2122@" /etc/ssh/sshd_config && \
    git config --global pull.rebase false && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    groupadd -r mysql && useradd -r -g mysql mysql && \
    mkdir /var/lib/mysql && chown -R mysql:mysql /var/lib/mysql


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
RUN chmod +x *.sh && ./save.sh

ENTRYPOINT /root/start.sh
