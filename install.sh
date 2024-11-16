#!/bin/bash
set -e
cd /root
export TERM=xterm-256color

# Repos
dnf -y install epel-release http://rpms.remirepo.net/enterprise/remi-release-9.rpm 
curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm
curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo
dnf config-manager --disable virtualmin pgdg{16,15,14,13,12} && dnf config-manager --enable crb

# Modules
dnf -y module reset nginx
dnf -y module enable nginx:1.24
dnf -y module reset nodejs
dnf -y module enable nodejs:20
dnf -y module reset mariadb
dnf -y module enable mariadb

PG=17

# Tools
dnf -y install btop bzip2 certbot clang cmake gcc-c++ git ncdu htop iftop ipset jq lsof make nano ninja-build ncurses nodejs ruby rsync screen socat strace tar time tmux vim wget whois xz yarn zstd \
  lib{curl,ffi,sqlite3x,tool-ltdl,md,yaml}-devel {brotli,bzip2,mesa-libGL,nettle,openldap,passenger,python,perl,readline,ruby,xmlsec1,xmlsec1-openssl}-devel python3-pip \
  libreport-filesystem {langpacks,glibc-langpack}-en perl-{DBD-Pg,DBD-mysql,LWP-Protocol-https,macros,DateTime,Crypt-SSLeay,Text-ASCIITable,IO-Tty,XML-Simple} \
  earlyoom fail2ban-server iptables-services postfix mariadb-server wbm-virtual-server wbm-virtualmin-{nginx,nginx-ssl} virtualmin-config bind sudo \
  openssh-server systemd-container libpq5-$PG*
ln -s /usr/bin/gcc /usr/bin/$(uname -m)-linux-gnu-gcc # fix pip install with native libs for aarch64

# NGINX
git clone https://github.com/domcloud/nginx-builder/ /usr/local/lib/nginx-builder
cd /usr/local/lib/nginx-builder/
make install
ln -s /usr/local/sbin/nginx /usr/sbin/nginx

# PHP
dnf -y install php{74,83}-php-{bcmath,cli,common,devel,fpm,gd,imap,intl,mbstring,mysqlnd,opcache,pdo,pecl-mongodb,pecl-redis,pecl-zip,pgsql,process,sodium,soap,xml}
dnf -y remove php-* && ln -s `which php83` /usr/bin/php || true
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
find /etc/opt/remi/ -maxdepth 1 -name 'php*' -exec sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 512M/g" {}/php.ini \; -exec sed -i "s/post_max_size = 8M/post_max_size = 512M/g" {}/php.ini \; 
find /etc/opt/remi/ -type f -name www.conf -print0 | xargs -0 sed -i 's/pm = dynamic/pm = ondemand/g'

# Postgres
dnf -y install postgresql$PG-{server,contrib,devel} {postgis34,pgrouting,pgvector,pg_uuidv7,timescaledb}_$PG
for bin in "psql" "pg_dump" "pg_dumpall" "pg_restore" "pg_config"; do
    alternatives --install /usr/bin/$bin "pgsql-$bin" "/usr/pgsql-$PG/bin/$bin" ${PG}00
done
for ext in "postgis" "postgis_raster" "postgis_sfcgal" "postgis_tiger_geocoders" "postgis_topology" "earthdistance" "address_standardizer" "address_standardizer_data_us" "pgrouting" "pg_uuidv7" "vector"; do
  echo "trusted = true" >> "/usr/pgsql-$PG/share/extension/$ext.control"
done

# Proxyfix
PROXYFIX=proxy-fix-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" )
wget https://github.com/domcloud/proxy-fix/releases/download/v0.2.5/$PROXYFIX.tar.gz
tar -xf $PROXYFIX.tar.gz && mv $PROXYFIX /usr/local/bin/proxfix && rm -rf $PROXYFIX*

# Docker
dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin fuse-overlayfs slirp4netns
modprobe ip_tables && echo "ip_tables" >> /etc/modules
# Pathman
PATHMAN=pathman-v0.6.0-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64_v1" )
wget -O pathman.tar.gz https://github.com/therootcompany/pathman/releases/download/v0.6.0/$PATHMAN.tar.gz
tar -xf pathman.tar.gz && mv $PATHMAN /usr/local/bin/pathman && rm -f pathman.tar.gz
# NVIM + NvChad Support
if [ "$(uname -m)" = "x86_64" ]; then
  curl -LO https://github.com/neovim/neovim/releases/download/v0.10.2/nvim-linux64.tar.gz
  tar -xzf nvim-linux64.tar.gz && chown -R root:root nvim-linux64 && rsync -a nvim-linux64/ /usr/local/ && rm -rf nvim-linux64*
else
  git clone https://github.com/neovim/neovim -b release-0.10 --filter=blob:none
  cd neovim && make CMAKE_BUILD_TYPE=Release && make install && cd .. && rm -rf neovim
fi
dnf -y copr enable atim/lazygit && dnf -y install ripgrep lazygit
# Neofetch (Forked)
wget -O /usr/local/bin/neofetch https://github.com/hykilpikonna/hyfetch/raw/1.4.11/neofetch
chmod +x /usr/local/bin/neofetch
# Rdfind
wget https://rdfind.pauldreik.se/rdfind-1.6.0.tar.gz
tar -xf rdfind-1.6.0.tar.gz ; cd rdfind-1.6.0
./configure --disable-debug ; make install
cd .. ; rm -rf rdfind-1.6.0 rdfind-1.6.0.tar.gz
# Misc
pip3 install pipenv awscli
dnf -y mark install ipset
dnf -y remove firewalld lynx gcc-toolset-13-* nodejs-docs clang flatpak open-sans-fonts rubygem-rdoc gl-manpages
ln -s /usr/lib/systemd/system/postgresql-$PG.service /usr/lib/systemd/system/postgresql.service
systemctl enable webmin mariadb postgresql-$PG {ip,ip6}tables fail2ban named php{74,83}-php-fpm earlyoom

# Cleanup
# nobest due https://cloudlinux.zendesk.com/hc/en-us/articles/15731606500124
dnf -y update --nobest
dnf -y clean all
rm -rf /usr/share/{locale,doc,man}
