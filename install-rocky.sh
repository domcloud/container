#!/bin/bash
set -ex
cd /root
export TERM=xterm-256color

# Repos
dnf -y install epel-release http://rpms.remirepo.net/enterprise/remi-release-10.rpm && dnf config-manager --enable crb
dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm
dnf config-manager --disable virtualmin pgdg{17,16,15,14}

# virtualmin 8
curl -fsSL https://raw.githubusercontent.com/virtualmin/virtualmin-install/refs/heads/master/virtualmin-install.sh | sh -s -- --setup --verbose
curl -sSL https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Modules

PG=18

# Tools
dnf -y install awscli bison btop bzip2 certbot clang cmake gcc-c++ git ncdu htop iftop jq lsof make nano ninja-build ncurses npm nodejs patch ripgrep ruby rsync screen socat strace tar time tmux vim wget whois xz yarn zstd \
  lib{curl,ffi,sqlite3x,tool-ltdl,md,yaml}-devel {brotli,bzip2,fuse,mesa-libGL,nettle,openldap,pcre2,perl,python,readline,redis,ruby,xmlsec1,xmlsec1-openssl,valkey}-devel python3-pip rubygem-{json,rack,rake} \
  libreport-filesystem {langpacks,glibc-langpack}-en perl-{DBD-Pg,DBD-mysql,LWP-Protocol-https,macros,DateTime,Crypt-SSLeay,Text-ASCIITable,IO-Tty,XML-Simple} sudo libpq5-$PG* fcgi chromium zsh --nobest
dnf -y install wbm-virtual-server wbm-virtualmin-{nginx,nginx-ssl} virtualmin-config earlyoom fail2ban-server nftables iptables-nft postfix mariadb-server valkey openssh-server systemd-container bind
ln -s /usr/bin/gcc /usr/bin/$(uname -m)-linux-gnu-gcc || true # fix pip install with native libs for aarch64
ln -s /usr/bin/valkey-cli /usr/local/bin/redis-cli || true # redis compatibility

# PHP
dnf -y install php{74,82,83,84,85}-php-{bcmath,cli,common,devel,ffi,fpm,gd,imap,intl,mbstring,mysqlnd,opcache,pdo,pecl-memcached,pecl-mongodb,pecl-redis,pecl-zip,pgsql,process,sodium,soap,xml,tidy}
if [[ -n "$OPTIONAL_INSTALL" ]]; then
  curl https://packages.microsoft.com/config/rhel/10/prod.repo | tee /etc/yum.repos.d/mssql-release.repo
  dnf -y install php{74,82,83}-php-ioncube-loader php{74,82,83,84,85}-php-{brotli,ldap,pecl-decimal,pecl-imagick-im7,pecl-rdkafka,pecl-simdjson,pecl-uuid,sqlsrv,xz,zstd}
  env ACCEPT_EULA=Y dnf -y install msodbcsql17 --skip-broken
fi
dnf -y remove php-* && ln -fs `which php84` /usr/bin/php || true
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Postgres
dnf -y install postgresql$PG-{server,contrib}
for bin in "psql" "pg_ctl" "pg_dump" "pg_dumpall" "pg_restore" "pg_config" "pg_isready" "postgres"; do
    alternatives --install /usr/bin/$bin "pgsql-$bin" "/usr/pgsql-$PG/bin/$bin" ${PG}00
done

if [[ -n "$OPTIONAL_INSTALL" ]]; then
  # Not everyone needs this. Also, postgresql-devel install would also install clang n gcc toolset
  dnf -y install {postgis35,pgrouting,pgvector,pg_uuidv7,timescaledb}_$PG postgresql$PG-devel
  for ext in "postgis" "postgis_raster" "postgis_sfcgal" "postgis_tiger_geocoders" "postgis_topology" "earthdistance" "address_standardizer" "address_standardizer_data_us" "pgrouting" "pg_uuidv7" "vector"; do
    echo "trusted = true" >> "/usr/pgsql-$PG/share/extension/$ext.control"
  done
fi

# Docker
dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin slirp4netns passt

# Misc
pip3 install pipenv
dnf -y remove lynx gcc-toolset-13-* nodejs-docs flatpak open-sans-fonts rubygem-rdoc gl-manpages firewalld
ln -s /usr/lib/systemd/system/postgresql-$PG.service /usr/lib/systemd/system/postgresql.service
systemctl enable webmin mariadb postgresql-$PG nftables fail2ban named php{74,85}-php-fpm earlyoom valkey || true
chmod +x /usr/local/bin/* && chown root:root /usr/local/bin/*
update-alternatives --set iptables /usr/sbin/iptables-nft

# Cleanup
# nobest since sometimes broken like https://cloudlinux.zendesk.com/hc/en-us/articles/15731606500124
dnf -y update --nobest
dnf -y clean all
