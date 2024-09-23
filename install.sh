#!/bin/bash
set -e

# Tools
dnf -y install epel-release http://rpms.remirepo.net/enterprise/remi-release-9.rpm 
curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup
dnf config-manager --disable virtualmin && dnf config-manager --enable crb
curl -sSLo /etc/yum.repos.d/passenger.repo https://oss-binaries.phusionpassenger.com/yum/definitions/el-passenger.repo
dnf -y install btop certbot clang cmake gcc-c++ git ncdu htop iftop ipset jq lsof make nano ncurses rsync sendmail socat strace tar time tmux vim wget xz zstd \
lib{curl,ffi,sqlite3x,tool-ltdl,md,yaml}-devel {brotli,mesa-libGL,nettle,openldap,passenger,python,perl,readline,xmlsec1,xmlsec1-openssl}-devel python3-pip \
libreport-filesystem {langpacks,glibc-langpack}-en perl-{DBD-Pg,DBD-mysql,LWP-Protocol-https,macros,DateTime,Crypt-SSLeay,Text-ASCIITable,IO-Tty,XML-Simple} \
earlyoom fail2ban-server iptables-services postfix mariadb-server wbm-virtual-server wbm-virtualmin-{nginx,nginx-ssl} systemd-container systemd openssh-server
ln -s /usr/bin/gcc /usr/bin/$(uname -m)-linux-gnu-gcc # fix spacy pip install

# PHP
dnf -y install php{74,81,82,83}-php-{bcmath,cli,common,devel,fpm,gd,imap,intl,mbstring,mysqlnd,opcache,pdo,pecl-imagick,pecl-mongodb,pecl-redis,pecl-zip,pgsql,process,sodium,soap,xml}
dnf -y remove php-* ; ln -s `which php83` /usr/bin/php || true
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
find /etc/opt/remi/ -maxdepth 1 -name 'php*' -exec sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 512M/g" {}/php.ini \; -exec sed -i "s/post_max_size = 8M/post_max_size = 512M/g" {}/php.ini \; 
find /etc/opt/remi/ -type f -name www.conf -print0 | xargs -0 sed -i 's/pm = dynamic/pm = ondemand/g'

# Modules
dnf -y module reset nginx
dnf -y module enable nginx:1.24
dnf -y module reset nodejs
dnf -y module enable nodejs:20
dnf -y module reset mariadb
dnf -y module enable mariadb

# Postgres
dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm
dnf -y install postgresql16-{server,contrib,devel} {postgis34,pgrouting,pgvector,pg_uuidv7,timescaledb}_16
for bin in "psql" "pg_dump" "pg_dumpall" "pg_restore"; do
    update-alternatives --set "pgsql-$bin" "/usr/pgsql-16/bin/$bin"
done
for ext in "postgis" "postgis_raster" "postgis_sfcgal" "postgis_tiger_geocoders" "postgis_topology" "earthdistance" "address_standardizer" "address_standardizer_data_us" "pgrouting" "pg_uuidv7" "vector"; do
  echo "trusted = true" >> "/usr/pgsql-16/share/extension/$ext.control"
done

# Pathman
PATHMAN=pathman-v0.6.0-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64_v1" )
wget -O pathman.tar.gz https://github.com/therootcompany/pathman/releases/download/v0.6.0/$PATHMAN.tar.gz
tar -xf $PATHMAN.tar.gz && mv $PATHMAN /usr/local/bin/pathman && rm -f $PATHMAN.tar.gz
# NVIM + NvChad Support
git clone https://github.com/neovim/neovim -b release-0.10 --filter=blob:none
cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo && make install
dnf -y copr enable atim/lazygit && dnf -y install ripgrep lazygit
# Neofetch (Forked)
wget -O /usr/local/bin/neofetch https://github.com/hykilpikonna/hyfetch/raw/1.4.11/neofetch
chmod +x /usr/local/bin/neofetch
# Rdfind
wget https://rdfind.pauldreik.se/rdfind-1.6.0.tar.gz
tar -xf rdfind-1.6.0.tar.gz ; cd rdfind-1.6.0
./configure --disable-debug ; make install
cd .. ; rm -rf rdfind-1.6.0
# Misc
pip3 install pipenv awscli

# Cleanup
dnf -y update
dnf -y clean all
