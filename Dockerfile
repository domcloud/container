FROM ubuntu:jammy
MAINTAINER Wildan M <willnode@wellosoft.net>

WORKDIR /root
ARG DEBIAN_FRONTEND=noninteractive

# Repositories (204 MB apt install)
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

# Webmin (304 MB + 60 MB)
RUN apt-get install -y webmin && \
    apt-get install -y nginx-common && \
    sed -i 's/listen \[::\]:80 default_server;/#listen \[::\]:80 default_server;/' /etc/nginx/sites-available/default && \
    apt-get install -y virtualmin-lemp-stack-minimal --no-install-recommends && \
    apt-get install -y virtualmin-core

# Terminal tools
RUN apt-get install -y git mercurial nano vim procps ntpdate \
    iproute2 net-tools openssl whois screen autoconf automake \
    dirmngr gnupg gpg make libtool zip unzip tar sqlite3 \
    python3 e2fsprogs dnsutils quota sudo language-pack-en gcc g++ cmake nodejs

# PHP
RUN apt-get install -y php-pear php8.2 php8.2-common php8.2-cli php8.2-cgi php8.2-fpm && \
    update-alternatives --set php /usr/bin/php8.2

# PHP extensions
# RUN apt-get install -y php8.2-curl php8.2-ctype php8.2-uuid php8.2-pgsql \
#     php8.2-sqlite3 php8.2-gd php8.2-redis php8.2-mysql php8.2-mbstring php8.2-iconv \
#     php8.2-grpc php8.2-xml php8.2-zip php8.2-bcmath php8.2-gettext \
#     php8.2-intl php8.2-readline php8.2-msgpack php8.2-igbinary

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
    systemctl enable php8.2-fpm && \
    systemctl enable named && \
    systemctl enable webmin

# Passenger Nginx
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 && \
    echo deb https://oss-binaries.phusionpassenger.com/apt/passenger focal main > /etc/apt/sources.list.d/passenger.list && \
    apt-get update && apt-get install -y libnginx-mod-http-passenger

# Misc
RUN ssh-keygen -A && \
    sed -i "s@#Port 22@Port 2122@" /etc/ssh/sshd_config && \
    git config --global pull.rebase false && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    chown -R mysql:mysql /var/lib/mysql && \
    mkdir -p /run/php && chmod 777 /run/php && \
    apt-get install -y libdbd-pg-perl npm cron


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

ENTRYPOINT /root/start.sh
