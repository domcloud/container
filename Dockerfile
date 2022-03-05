FROM rockylinux:latest
MAINTAINER Wildan M <willnode@wellosoft.net>

WORKDIR /root

# GNU tools
RUN dnf install -y curl git nano vim wget procps \
    iproute net-tools dnf-utils openssl whois \
    which gcc gcc-c++ gnupg2 gpg make cmake \
    perl go rustc cargo rake ruby zip unzip tar \
    iptables-services openssh-server mariadb \
    postgresql-server postgresql-contrib \
    python36 python38 python39

ARG WEBMIN_ROOT_PORT_PREFIX

# Copy scripts
COPY ./scripts/install.sh ./scripts/slib.sh ./scripts/systemctl3.py  /root/
RUN chmod +x /root/*

# SystemD replacement
RUN cp -f systemctl3.py /usr/bin/systemctl

# Virtualmin
RUN echo ${WEBMIN_ROOT_HOSTNAME} > /etc/hostname \
    && TERM=xterm-256color COLUMNS=120 ./install.sh --minimal --force --verbose --bundle LEMP

# EPEL
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(< /etc/redhat-release tr -dc '0-9.'|cut -d \. -f1).noarch.rpm && \
    dnf config-manager --enable epel && \
    dnf clean all && dnf update -y

# Nodejs & C++
RUN curl --fail -sSL -o setup-nodejs https://rpm.nodesource.com/setup_14.x && \
    bash setup-nodejs && \
    dnf install -y nodejs && \
    sed -i "s/failovermethod=priority//g" /etc/yum.repos.d/nodesource-el8.repo

# PHP
RUN dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
RUN dnf module reset -y php && dnf module enable -y php:remi-7.4
RUN dnf install -y composer php php-bcmath php-cli php-common php-devel php-fpm php-gd php-intl php-json php-mbstring php-mysqlnd php-opcache php-pdo php-pear php-pecl-igbinary php-pecl-memcached php-pecl-msgpack php-pecl-yaml php-pecl-zip php-pgsql php-process php-xml php-xmlrpc \
    php56-php php56-php-bcmath php56-php-cli php56-php-common php56-php-devel php56-php-fpm php56-php-gd php56-php-intl php56-php-json php56-php-mbstring php56-php-mysqlnd php56-php-opcache php56-php-pdo php56-php-pear php56-php-pecl-igbinary php56-php-pecl-memcached php56-php-pecl-msgpack php56-php-pecl-yaml php56-php-pecl-zip php56-php-pgsql php56-php-process php56-php-xml php56-php-xmlrpc \
    php80-php php80-php-bcmath php80-php-cli php80-php-common php80-php-devel php80-php-fpm php80-php-gd php80-php-intl php80-php-json php80-php-mbstring php80-php-mysqlnd php80-php-opcache php80-php-pdo php80-php-pear php80-php-pecl-igbinary php80-php-pecl-memcached php80-php-pecl-msgpack php80-php-pecl-yaml php80-php-pecl-zip php80-php-pgsql php80-php-process php80-php-xml php80-php-xmlrpc \
    php81-php php81-php-bcmath php81-php-cli php81-php-common php81-php-devel php81-php-fpm php81-php-gd php81-php-intl php81-php-json php81-php-mbstring php81-php-mysqlnd php81-php-opcache php81-php-pdo php81-php-pear php81-php-pecl-igbinary php81-php-pecl-memcached php81-php-pecl-msgpack php81-php-pecl-yaml php81-php-pecl-zip php81-php-pgsql php81-php-process php81-php-xml php81-php-xmlrpc

# Passenger Nginx
RUN curl --fail -sSLo /etc/yum.repos.d/passenger.repo https://oss-binaries.phusionpassenger.com/yum/definitions/el-passenger.repo
RUN dnf install -y nginx-mod-http-passenger || { dnf config-manager --enable cr && dnf install -y nginx-mod-http-passenger ; }

ARG WEBMIN_ROOT_HOSTNAME
# affected by yum update, need recopy? (and forever like that?)
RUN cp -f systemctl3.py /usr/bin/systemctl

# Misc
RUN npm install -g yarn pnpm && \
    postgresql-setup --initdb --unit postgresql && \
    sed -i "s@#Port 22@Port 2122@" /etc/ssh/sshd_config && \
    git config --global pull.rebase false && \
    alternatives --install /usr/bin/unversioned-python python /usr/bin/python3.9 1

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
