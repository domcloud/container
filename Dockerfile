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
    gcc g++ gnupg2 gpg make cmake apt-utils \
    perl golang-go rustc cargo rake ruby zip unzip tar \
    iptables openssh-server mariadb-server \
    postgresql postgresql-contrib python3 e2fsprogs \
    bind9 bind9-host dnsutils fail2ban quota rsyslog \
    libcrypt-ssleay-perl software-properties-common language-pack-en

# PHP
RUN LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y && \
	add-apt-repository ppa:adiscon/v8-stable -y && \
    apt-get update && apt-get upgrade -y
RUN apt-get install -y composer php php-bcmath php-cli php-common php-devel php-fpm php-gd php-intl php-json php-mbstring php-mysqlnd php-opcache php-pdo php-pear php-pecl-igbinary php-pecl-memcached php-pecl-msgpack php-pecl-yaml php-pecl-zip php-pgsql php-process php-xml php-xmlrpc \
    php56 php56-bcmath php56-cli php56-common php56-devel php56-fpm php56-gd php56-intl php56-json php56-mbstring php56-mysqlnd php56-opcache php56-pdo php56-pear php56-pecl-igbinary php56-pecl-memcached php56-pecl-msgpack php56-pecl-yaml php56-pecl-zip php56-pgsql php56-process php56-xml php56-xmlrpc \
    php80 php80-bcmath php80-cli php80-common php80-devel php80-fpm php80-gd php80-intl php80-json php80-mbstring php80-mysqlnd php80-opcache php80-pdo php80-pear php80-pecl-igbinary php80-pecl-memcached php80-pecl-msgpack php80-pecl-yaml php80-pecl-zip php80-pgsql php80-process php80-xml php80-xmlrpc \
    php81 php81-bcmath php81-cli php81-common php81-devel php81-fpm php81-gd php81-intl php81-json php81-mbstring php81-mysqlnd php81-opcache php81-pdo php81-pear php81-pecl-igbinary php81-pecl-memcached php81-pecl-msgpack php81-pecl-yaml php81-pecl-zip php81-pgsql php81-process php81-xml php81-xmlrpc

# Copy scripts
COPY ./scripts/install.sh ./scripts/slib.sh ./scripts/systemctl3.py  /root/
RUN chmod +x /root/*

# SystemD replacement
RUN cp -f systemctl3.py /usr/bin/systemctl

# Virtualmin
RUN TERM=xterm-256color COLUMNS=120 ./install.sh --minimal --force --verbose --bundle LEMP

# Nodejs & C++
RUN curl --fail -sSL -o setup-nodejs https://deb.nodesource.com/setup_14.x && \
    bash setup-nodejs && \
    apt-get install -y nodejs

# Passenger Nginx
RUN apt-get install -y dirmngr gnupg && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 && \
    apt-get install -y apt-transport-https ca-certificates && \
    echo deb https://oss-binaries.phusionpassenger.com/apt/passenger bionic main > /etc/apt/sources.list.d/passenger.list && \
    apt-get update && \
    apt-get install -y libnginx-mod-http-passenger

ARG WEBMIN_ROOT_PORT_PREFIX
ARG WEBMIN_ROOT_HOSTNAME

# Misc
RUN ssh-keygen -A && \
    npm install -g yarn pnpm && \
    mysql_install_db --skip-test-db && \
    postgresql-setup --initdb --unit postgresql && \
    sed -i "s@#Port 22@Port 2122@" /etc/ssh/sshd_config && \
    git config --global pull.rebase false && \
    alternatives --install /usr/bin/unversioned-python python /usr/bin/python3.9 1 && \
    cp -f systemctl3.py /usr/bin/systemctl


# bugfix https://github.com/virtualmin/Virtualmin-Config/commit/e8f4498d4cdc3618efee2120b80ccbc723e034e2
COPY ./scripts/Virtualmin-Config.pm /usr/share/perl5/vendor_perl/Virtualmin/Config.pm
RUN virtualmin-config-system -b MiniLEMP -x Net


# Firewall
RUN systemctl disable firewalld && \
    systemctl mask --now firewalld && \
    systemctl disable httpd && \
    systemctl enable iptables && \
    systemctl enable ip6tables && \
    systemctl enable postgresql && \
    systemctl enable mariadb && \
    systemctl enable nginx && \
    systemctl enable webmin && \
    systemctl enable php-fpm && \
    systemctl enable sshd

# Temporary fix for nginx
# RUN yum downgrade wbm-virtualmin-nginx-2.21 -y && \
#     yum downgrade wbm-virtualmin-nginx-ssl-1.15 -y

# set root password
ARG WEBMIN_ROOT_PASSWORD
RUN /usr/libexec/webmin/changepass.pl /etc/webmin root ${WEBMIN_ROOT_PASSWORD}

# save mount artifacts
COPY ./scripts/save.sh ./scripts/start.sh  /root/
RUN chmod +x /root/* && ./save.sh

ENTRYPOINT /root/start.sh
