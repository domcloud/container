#!/bin/bash
set -e
cd /root
export TERM=xterm-256color

#Prerequites
apt-get update
apt-get -y install libdbd-{pg,mysql}-perl libcrypt-ssleay-perl libxml-simple-perl libtext-asciitable-perl liblwp-protocol-https-perl

#Repos

apt update && apt install yarn -y
apt update && apt install npm -y
#Docker
    # Add Docker's official GPG key:
        apt-get update
        apt-get install ca-certificates
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
         > /dev/null
        apt-get update
    #Docker Install
        
#Postgresql
    apt-get update
    install -d /usr/share/postgresql-common/pgdg
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

    # Create the repository configuration file:
        sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

    # Update the package lists:
        apt-get update

    # Install the latest version of PostgreSQL:
    # If you want a specific version, use 'postgresql-16' or similar instead of 'postgresql'
        apt-get -y install postgresql

# Install PHP and extensions
    add-apt-repository ppa:ondrej/php; apt-get update
    apt-get install php{7.4,8.4}-{bcmath,cli,common,dev,fpm,gd,imap,igbinary,intl,mbstring,mysql,opcache,mongodb,readline,redis,zip,pgsql,soap,xml} -y
    find /etc/php/ -maxdepth 1 -mindepth 1 -exec sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 512M/g" {}/fpm/php.ini \; -exec sed -i "s/post_max_size = 8M/post_max_size = 512M/g" {}/fpm/php.ini \; 

#React-Native  
    sudo apt install openjdk-11-jdk
    sudo npm install -g react-native-cli
    sdkmanager "platform-tools" "platforms;android-31" "build-tools;31.0.0" "ndk;21.4.7075529"

    mkdir -p ~/Android/Sdk
    cd ~/Android/Sdk

    wget https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip
    unzip commandlinetools-linux-8092744_latest.zip
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/* cmdline-tools/latest/
    rmdir cmdline-tools
    mv cmdline-tools latest

    sudo apt install google-android-cmdline-tools-11.0-installer
    sdkmanager --licenses -y
    sdkmanager "platform-tools" "platforms;android-31" "build-tools;31.0.0"
    echo 'export ANDROID_HOME=/usr/lib/android-sdk' >> ~/.bashrc
    echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc
    source ~/.bashrc

#Tools
    #ALL
        apt-get update
        apt-get install bzip2 valkey-server bison btop clang certbot cmake git ncdu htop iftop ipset jq lsof make nano ninja-build ncurses-bin patch ripgrep ruby rsync screen socat strace tar time tmux vim wget whois xz-utils zstd \
        libcurl4-openssl-dev libffi-dev libsqlite3-dev libtool libssl-dev libyaml-dev brotli libbz2-dev libgl1-mesa-dev libldap2-dev libpcre2-dev python3-dev libreadline-dev redis-server libxmlsec1-dev python3-pip ruby-json ruby-rack language-pack-en libc-bin libdbd-pg-perl libdbd-mysql-perl liblwp-protocol-https-perl libdatetime-perl libcrypt-ssleay-perl libtext-asciitable-perl libio-tty-perl libxml-simple-perl earlyoom fail2ban iptables postfix bind9 sudo openssh-server systemd-container libpq-dev -y

curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup --verbose

apt-get install -y nginx-full webmin-virtualmin-nginx webmin-virtualmin-nginx-ssl

virtualmin-config-system -i Nginx

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash - 
apt-get install nodejs

sudo apt-get install -y dirmngr gnupg apt-transport-https ca-certificates curl
curl https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/phusion.gpg >/dev/null
 sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger noble main > /etc/apt/sources.list.d/passenger.list'
apt-get install -y libnginx-mod-http-passenger
