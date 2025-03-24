#!/bin/bash
set -e
cd /root
export TERM=xterm-256color

# Repos
dnf -y install epel-release http://rpms.remirepo.net/enterprise/remi-release-9.rpm && dnf config-manager --enable crb
dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm
curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup --verbose
curl -sSL https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf config-manager --disable virtualmin pgdg{16,15,14,13,12}

# Modules
dnf -y module reset nodejs
dnf -y module enable nodejs:22
dnf -y module reset mariadb
dnf -y module enable mariadb

PG=17

# Tools
dnf -y install awscli bison btop bzip2 certbot clang cmake gcc-c++ git ncdu htop iftop jq lsof make nano ninja-build ncurses npm nodejs patch ripgrep ruby rsync screen socat strace tar time tmux vim wget whois xz yarn zstd \
  lib{curl,ffi,sqlite3x,tool-ltdl,md,yaml}-devel {brotli,bzip2,mesa-libGL,nettle,openldap,pcre2,perl,python,readline,redis,ruby,xmlsec1,xmlsec1-openssl,valkey}-devel python3-pip rubygem-{json,rack,rake} \
  libreport-filesystem {langpacks,glibc-langpack}-en perl-{DBD-Pg,DBD-mysql,LWP-Protocol-https,macros,DateTime,Crypt-SSLeay,Text-ASCIITable,IO-Tty,XML-Simple} sudolibpq5-$PG* fcgi chromium --nobest
dnf -y wbm-virtual-server wbm-virtualmin-{nginx,nginx-ssl} virtualmin-config earlyoom fail2ban-server nftables postfix mariadb-server valkey openssh-server systemd-container bind
ln -s /usr/bin/gcc /usr/bin/$(uname -m)-linux-gnu-gcc || true # fix pip install with native libs for aarch64
ln -s /usr/bin/valkey-cli /usr/local/bin/redis-cli || true # redis compatibility

# NGINX
BUILDER_DIR=/usr/local/lib/nginx-builder; [ ! -d "$BUILDER_DIR" ] && \
git clone https://github.com/domcloud/nginx-builder/ $BUILDER_DIR || git -C $BUILDER_DIR pull
cd $BUILDER_DIR/ && make install DOWNLOAD_V=1.1.1 && make clean && cd /root
ln -fs /usr/local/sbin/nginx /usr/sbin/nginx # nginx compatibility

# PHP
dnf -y install php{74,84}-php-{bcmath,cli,common,devel,ffi,fpm,gd,imap,intl,mbstring,mysqlnd,opcache,pdo,pecl-memcached,pecl-mongodb,pecl-redis,pecl-zip,pgsql,process,sodium,soap,xml,tidy}
# curl https://packages.microsoft.com/config/rhel/9/prod.repo | tee /etc/yum.repos.d/mssql-release.repo
# dnf -y install php{74,81,82}-php-ioncube-loader php{74,81,82,83,84}-php-{brotli,ldap,pecl-decimal,pecl-imagick-im7,pecl-rdkafka,pecl-simdjson,pecl-uuid,sqlsrv,xz,zstd} msodbcsql17 # optional, installed in cloud
dnf -y remove php-* && ln -fs `which php84` /usr/bin/php || true
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Postgres
dnf -y install postgresql$PG-{server,contrib}
for bin in "psql" "pg_ctl" "pg_dump" "pg_dumpall" "pg_restore" "pg_config" "pg_isready" "postgres"; do
    alternatives --install /usr/bin/$bin "pgsql-$bin" "/usr/pgsql-$PG/bin/$bin" ${PG}00
done

# Not everyone needs this. Also, postgresql-devel install would also install clang n gcc toolset
# dnf -y install {postgis35,pgrouting,pgvector,pg_uuidv7,timescaledb}_$PG postgresql$PG-devel
# for ext in "postgis" "postgis_raster" "postgis_sfcgal" "postgis_tiger_geocoders" "postgis_topology" "earthdistance" "address_standardizer" "address_standardizer_data_us" "pgrouting" "pg_uuidv7" "vector"; do
#   echo "trusted = true" >> "/usr/pgsql-$PG/share/extension/$ext.control"
# done

# Docker
dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin slirp4netns passt

# Proxyfix
PROXYFIX=proxy-fix-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" )
if ! command -v proxfix &> /dev/null; then
  curl -sSLO https://github.com/domcloud/proxy-fix/releases/download/v0.2.5/$PROXYFIX.tar.gz
  tar -xf $PROXYFIX.tar.gz && mv -f $PROXYFIX /usr/local/bin/proxfix && rm -rf $PROXYFIX*
fi

# Rdproxy
RDPROXY=rdproxy-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" )
if ! command -v rdproxy &> /dev/null; then
  curl -sSLO https://github.com/domcloud/rdproxy/releases/download/v0.3.1/$RDPROXY.tar.gz
  tar -xf $RDPROXY.tar.gz && mv -f $RDPROXY /usr/local/bin/rdproxy && rm -rf $RDPROXY*
fi

# Pathman
PATHMAN_V=0.6.0
if ! command -v pathman &> /dev/null; then
  PATHMAN=pathman-v${PATHMAN_V}-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64_v1" )
  curl -sSLO https://github.com/therootcompany/pathman/releases/download/v$PATHMAN_V/$PATHMAN.tar.gz
  tar -xf $PATHMAN.tar.gz && mv -f $PATHMAN /usr/local/bin/pathman && rm -f $PATHMAN.tar.gz
fi

# NVIM for NvChad
NVIM_V=0.10.4
if ! command -v neovim &> /dev/null; then
  NVIM_F=nvim-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
  curl -sSLO https://github.com/neovim/neovim/releases/download/v$NVIM_V/$NVIM_F.tar.gz
  tar -xf $NVIM_F.tar.gz && chown -R root:root $NVIM_F && rsync -a $NVIM_F/ /usr/local/ && rm -rf $NVIM_F*
fi

# Lazygit for NVIM
LAZYGIT_V=0.48.0
if ! command -v lazygit &> /dev/null; then
  LAZYGIT=lazygit_${LAZYGIT_V}_Linux_$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
  curl -sSLO https://github.com/jesseduffield/lazygit/releases/download/v$LAZYGIT_V/$LAZYGIT.tar.gz
  tar -xf $LAZYGIT.tar.gz && mv lazygit /usr/local/bin/ && rm -f $LAZYGIT.tar.gz
fi

# Lazydocker
LAZYDOCK_V=0.24.1
if ! command -v lazydocker &> /dev/null; then
  LAZYDOCK=lazydocker_${LAZYDOCK_V}_Linux_$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
  curl -sSLO https://github.com/jesseduffield/lazydocker/releases/download/v$LAZYDOCK_V/$LAZYDOCK.tar.gz
  tar -xf $LAZYGIT.tar.gz && mv lazydocker /usr/local/bin/ && rm -f $LAZYGIT.tar.gz
fi

# Neofetch (Forked)
curl -sSLo /usr/local/bin/neofetch https://github.com/hykilpikonna/hyfetch/raw/1.99.0/neofetch

# Rdfind
RDFIND=rdfind-1.6.0
curl -sSL https://rdfind.pauldreik.se/$RDFIND.tar.gz | tar -xzf -
cd $RDFIND; ./configure --disable-debug ; make install; cd .. ; rm -rf $RDFIND*

# Misc
pip3 install pipenv
dnf -y remove lynx gcc-toolset-13-* nodejs-docs clang flatpak open-sans-fonts rubygem-rdoc gl-manpages
ln -s /usr/lib/systemd/system/postgresql-$PG.service /usr/lib/systemd/system/postgresql.service
systemctl enable webmin mariadb postgresql-$PG nftables fail2ban named php{74,84}-php-fpm earlyoom valkey || true
chmod +x /usr/local/bin/* && chown root:root /usr/local/bin/*

# Cleanup
# nobest since sometimes broken like https://cloudlinux.zendesk.com/hc/en-us/articles/15731606500124
dnf -y update --nobest
dnf -y clean all
