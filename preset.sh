#!/bin/bash
set -e
cd /root

if [ -f /etc/lsb-release ]; then OS=ubuntu; elif [ -f /etc/redhat-release ]; then OS=rocky; else OS=unknown; fi
PASSWD=$OS

# Contents
curl -sSLo /usr/local/bin/restart https://raw.githubusercontent.com/domcloud/bridge/main/userkill.sh && chmod 755 /usr/local/bin/restart
WWW=/usr/local/share/www && WWWSOURCE=https://raw.githubusercontent.com/domcloud/domcloud/master/share && mkdir -p $WWW
curl -sSLo $WWW/deceptive.html $WWWSOURCE/deceptive.html
curl -sSLo $WWW/nosite.html $WWWSOURCE/nosite.html
chmod 0755 -R $WWW

SKEL=/etc/skel/public_html
mkdir -p $SKEL/.well-known && touch $SKEL/favicon.ico
curl -sSLo $SKEL/index.html $WWWSOURCE/index.html

mkdir -p /etc/ssl/default/
curl -sSLo /etc/ssl/default/key.pem https://raw.githubusercontent.com/willnode/forward-domain/refs/heads/main/test/certs/localhost/key.pem
curl -sSLo /etc/ssl/default/cert.pem https://raw.githubusercontent.com/willnode/forward-domain/refs/heads/main/test/certs/localhost/cert.pem

# Config
echo "gem: --no-document" > /etc/gemrc
cat <<'EOF' > /etc/gitconfig
[pull]
        rebase = false
[init]
        defaultBranch = main
EOF
cat <<'EOF' > /etc/environment
LC_ALL="en_US.UTF-8"
LC_CTYPE="en_US.UTF-8"
LANGUAGE="en_US.UTF-8"
EOF
cat <<'EOF' > /etc/default/earlyoom
EARLYOOM_ARGS="-r 0 -m 4 -M 409600 -g --prefer '^(node|python|ruby|java)' --avoid '^(dnf|mariadbd|named|nginx|polkitd|postmaster|sshd|php-fpm|valkey-server)$'"
EOF

# SSH
cat <<'EOF' | while read -r line; do
PasswordAuthentication yes
ClientAliveInterval 10
ClientAliveCountMax 60
PermitEmptyPasswords no
EOF
    # Extract the key part (before ' ') to use as a pattern for sed
    key=$(echo "$line" | cut -d' ' -f1)
    config_file=/etc/ssh/sshd_config

    if grep -q "^#?$key " "$config_file"; then
        # If found, replace the line
        sed -i "s|^#?$key .*|$line|" "$config_file"
    else
        # If not found, append the line to the end of the file
        echo "$line" >> "$config_file"
    fi
done

cat <<'EOF' > /etc/sudo_banner
***********************************************
Sorry!  You can't have root access!  Read more:
https://domcloud.co/docs/intro/security#no-sudo
***********************************************
EOF
cat <<'EOF' | EDITOR='tee' visudo /etc/sudoers.d/banner
Defaults        lecture_file = /etc/sudo_banner
Defaults        lecture = always
EOF

# NTP
timedatectl set-local-rtc 0

# SystemD
cat <<'EOF' > /usr/lib/systemd/system/nginx.service
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/bin/rm -f /run/nginx.pid
ExecStartPre=/usr/bin/mkdir -p /var/run/passenger-instreg
ExecStartPre=/usr/local/sbin/nginx -t
ExecStart=/usr/local/sbin/nginx
ExecReload=/usr/local/sbin/nginx -s reload
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
cat <<'EOF' > /etc/security/limits.conf
root             soft    nofile          65535
*                hard    nproc           256
*                hard    priority        5
EOF

# Services config
PG=17
PGDATA=/var/lib/pgsql/$PG/data
PGDAEMON=postgresql-$PG
PGCONFIG=$PGDATA
PGBIN=/usr/pgsql-$PG/bin
VALKEYDAEMON=valkey
if [[ "$OS" == "ubuntu" ]]; then
  PGDATA=/var/lib/postgresql/$PG/main
  PGDAEMON=postgresql@$PG-main
  PGCONFIG=/etc/postgresql/$PG/main
  PGBIN=/usr/lib/postgresql/$PG/bin
  VALKEYDAEMON=valkey-server
fi

mkdir -p /etc/systemd/system/{nginx,earlyoom,fail2ban,mariadb,$PGDAEMON,$VALKEYDAEMON}.service.d
cat <<'EOF' > /etc/systemd/system/nginx.service.d/override.conf
[Service]
LimitNOFILE=65535
EOF
cat <<'EOF' > /etc/systemd/system/earlyoom.service.d/override.conf
[Service]
SupplementaryGroups=adm
EOF
cat <<'EOF' > /etc/systemd/system/fail2ban.service.d/override.conf
[Unit]
Requires=nftables.service
PartOf=nftables.service

[Install]
WantedBy=multi-user.target nftables.service
EOF
cat <<'EOF' > /etc/systemd/system/mariadb.service.d/override.conf
[Service]
Restart=on-failure
EOF
cat <<'EOF' > /etc/systemd/system/$PGDAEMON.service.d/override.conf
[Service]
Restart=on-failure
EOF
cat <<'EOF' > /etc/systemd/system/$VALKEYDAEMON.service.d/override.conf
[Service]
Restart=on-failure
EOF
SLICEDIR=/etc/systemd/system/user.slice.d; 
if [ ! -d "$SLICEDIR" ]; then
  mkdir -p $SLICEDIR
  # You may want to set limit
  # CPULIMIT=$(echo $(( $(nproc) * 70 ))%)
  # MEMLIMIT=$(echo $(( $(grep MemTotal /proc/meminfo | awk '{print $2}') * 80 / 100 / 1024 ))M)
  echo -e "[Slice]\nCPUAccounting=yes\nCPUQuota=$CPULIMIT" > $SLICEDIR/50-cpu-limit.conf
  echo -e "[Slice]\nMemoryAccounting=yes\nMemoryMax=$MEMLIMIT\nMemorySwapMax=0" > $SLICEDIR/50-mem-limit.conf
fi

# Docker (we use nftables)
cat <<EOF > /etc/docker/daemon.json
{
  "iptables": false
}
EOF

# DB
if [[ "$OS" == "ubuntu" ]]; then
  MARIA_CONF=/etc/mysql/mariadb.conf.d/50-server.cnf
  cat <<'EOF' > $MARIA_CONF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
pid-file=/run/mysqld/mysqld.pid
log-error=/var/log/mariadb/mysqld.log
innodb_file_per_table = 1
innodb_buffer_pool_size = 128MB
myisam_sort_buffer_size = 8M
read_rnd_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
sort_buffer_size = 512K
table_open_cache = 64
max_allowed_packet = 64M
key_buffer_size = 16M
max_connections = 4096
EOF
else
  MARIA_CONF=/etc/my.cnf.d/mariadb-server.cnf
  cat <<'EOF' > $MARIA_CONF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
pid-file=/run/mariadb/mariadb.pid
log-error=/var/log/mariadb/mariadb.log
innodb_file_per_table = 1
innodb_buffer_pool_size = 128MB
myisam_sort_buffer_size = 8M
read_rnd_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
sort_buffer_size = 512K
table_open_cache = 64
max_allowed_packet = 64M
key_buffer_size = 16M
max_connections = 4096
EOF
fi

systemctl start mariadb || true # init db

sudo -u postgres $PGBIN/initdb -D $PGDATA || true
sed -i "s/#listen_addresses = .*/listen_addresses = '*'/g" $PGCONFIG/postgresql.conf
sed -i "s/max_connections = 100/max_connections = 4096/g" $PGCONFIG/postgresql.conf
cat <<'EOF' > $PGCONFIG/pg_hba.conf
local   all             all                                     peer
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
EOF

# valkey
VALKEY=/etc/valkey
cp $VALKEY/valkey.conf $VALKEY/valkey.conf.default
sed -i "s/# aclfile /aclfile /g" $VALKEY/valkey.conf
sed -i "s/# maxmemory <bytes>/maxmemory 256mb/g" $VALKEY/valkey.conf
sed -i "s/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/g" $VALKEY/valkey.conf
sed -i "s/# maxmemory-samples 5/maxmemory-samples 3/g" $VALKEY/valkey.conf
[ -f $VALKEY/users.acl ] || cat <<EOF > $VALKEY/users.acl
user default off nopass sanitize-payload resetchannels +@all
user root on sanitize-payload >$PASSWD ~* &* +@all
EOF
touch $VALKEY/usermap.acl
chmod 0700 $VALKEY/*
chown valkey:valkey $VALKEY/*

sed -i 's/port=10000/port=2443/g' /etc/webmin/miniserv.conf

cat <<'EOF' | while read -r line; do
allow_subdoms=0
auto_letsencrypt=0
avail_xterm=1
aws_cmd=aws
bind_spf=
bind_sub=yes
bw_active=1
bw_backup=1
bw_disable=0
bw_maxdays=
bw_owner=0
bw_past=month
bw_step=12
cert_type=sha1
collect_noall=1
collect_interval=60
combined_cert=2
disable=web,mysql,postgres
dns_ip=10.0.2.15
dns_records=@
dovecot_ssl=0
hard_quotas=0
hashpass=0
hide_pro_tips=1
html_perms=0750
jail_age=
jailkit_disabled=0
key_tmpl=/etc/ssl/virtualmin/${ID}/ssl.key
letsencrypt_retry=0
letsencrypt_wild=0
logrotate_shared=yes
mysql_charset=utf8mb4
mysql_collate=utf8mb4_unicode_ci
mysql_db=${PREFIX}_db
mysql_hosts=%
mysql_mkdb=0
mysql_ssl=0
mysql_suffix=${USER}_
nolink_certs=2
passwd_mode=1
php_fpm=pm = ondemand	pm.max_children = 8	pm.process_idle_timeout = 18000s
php_log=1
php_noedit=0
php_sock=1
php_suexec=3
php_vars=
postfix_ssl=0
preload_mode=2
proftpd_ssl=0
quotas=1
status=0
usermin_ssl=0
virtual_skel=/etc/skel
webmin_ssl=0
EOF
    # Extract the key part (before '=') to use as a pattern for sed
    key=$(echo "$line" | cut -d'=' -f1)
    config_file=/etc/webmin/virtual-server/config

    if grep -q "^$key=" "$config_file"; then
        # If found, replace the line
        sed -i "s|^$key=.*|$line|" "$config_file"
    else
        # If not found, append the line to the end of the file
        echo "$line" >> "$config_file"
    fi
done

cat <<'EOF' | while read -r line; do
net.ipv4.ping_group_range=0 2147483647
vm.overcommit_memory=1
EOF
    # Extract the key part (before '=') to use as a pattern for sed
    key=$(echo "$line" | cut -d'=' -f1)
    config_file=/etc/sysctl.conf

    if grep -q "^$key=" "$config_file"; then
        # If found, replace the line
        sed -i "s|^$key=.*|$line|" "$config_file"
    else
        # If not found, append the line to the end of the file
        echo "$line" >> "$config_file"
    fi
done

cat <<EOF > /etc/webmin/webmincron/crons/173224301830730.cron
months=*
arg0=bw.pl
active=1
module=virtual-server
func=run_cron_script
days=*
mins=0
hours=0,12
user=root
id=173224301830730
weekdays=*
EOF

cat <<EOF > /etc/webmin/postgresql/config
login=postgres
repository=/home/db_repository
start_cmd=systemctl start postgresql
nodbi=0
sameunix=1
add_mode=1
blob_mode=0
basedb=template1
perpage=25
max_dbs=50
date_subs=0
dump_cmd=/usr/bin/pg_dump
pid_file=$PGDATA/postmaster.pid
psql=/usr/bin/psql
access_own=0
stop_cmd=systemctl stop postgresql
style=0
hba_conf=$PGCONFIG/pg_hba.conf
setup_cmd=postgresql-setup --initdb
max_text=1000
access=*: *
webmin_subs=0
simple_sched=0
user=postgres
rstr_cmd=/usr/bin/pg_restore
plib=
host=
sslmode=
port=
EOF

cat <<'EOF' > /etc/webmin/virtual-server/plans/0
ipfollow=
aliaslimit=
migrate=0
capabilities=domain users aliases dbs scripts ssl redirect admins phpver phpmode backup sharedips passwd spf records
bwlimit=
aliasdomslimit=
uquota=
name=Default Plan
safeunder=1
file=/etc/webmin/virtual-server/plans/0
mailboxlimit=
nodbname=0
quota=
forceunder=1
featurelimits=
norename=1
id=0
domslimit=
dbslimit=
realdomslimit=
scripts=
EOF

if [[ "$OS" == "ubuntu" ]]; then
  cat <<'EOF' > /etc/webmin/virtualmin-nginx/config
add_to=/etc/nginx/sites-available
apply_cmd=systemctl reload nginx
stop_cmd=systemctl stop nginx
start_cmd=systemctl start nginx
nginx_cmd=/usr/sbin/nginx
rotate_cmd=nginx -s reopen
http2=0
php_socket=1
child_procs=4
add_link=/etc/nginx/sites-enabled
nginx_config=/etc/nginx/nginx.conf
listen_mode=0
EOF
else
  cat <<'EOF' > /etc/webmin/virtualmin-nginx/config
add_to=/etc/nginx/conf.d
apply_cmd=systemctl reload nginx
stop_cmd=systemctl stop nginx
start_cmd=systemctl start nginx
php_socket=1
nginx_cmd=/usr/sbin/nginx
http2=0
listen_mode=0
child_procs=4
extra_dirs=
rotate_cmd=nginx -s reopen
add_link=
nginx_config=/etc/nginx/nginx.conf
EOF
fi


cat <<'EOF' > /etc/nginx/fastcgi.conf
fastcgi_param GATEWAY_INTERFACE CGI/1.1;
fastcgi_param SERVER_SOFTWARE nginx;
fastcgi_param QUERY_STRING $query_string;
fastcgi_param REQUEST_METHOD $request_method;
fastcgi_param CONTENT_TYPE $content_type;
fastcgi_param CONTENT_LENGTH $content_length;
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
fastcgi_param SCRIPT_NAME $fastcgi_script_name;
fastcgi_param REQUEST_URI $request_uri;
fastcgi_param DOCUMENT_URI $document_uri;
fastcgi_param DOCUMENT_ROOT $document_root;
fastcgi_param SERVER_PROTOCOL $server_protocol;
fastcgi_param REMOTE_ADDR $remote_addr;
fastcgi_param REMOTE_PORT $remote_port;
fastcgi_param SERVER_ADDR $server_addr;
fastcgi_param SERVER_PORT $server_port;
fastcgi_param SERVER_NAME $server_name;
fastcgi_param HTTP_HOST $host;
fastcgi_param PATH_INFO $fastcgi_path_info;
fastcgi_param HTTPS $https;
fastcgi_split_path_info ^(.+\.php)(/.+)$;
fastcgi_read_timeout 600s;
fastcgi_buffers 16 32k;
fastcgi_buffer_size 64k;
fastcgi_busy_buffers_size 64k;
EOF

cat <<'EOF' > /etc/nginx/passenger.conf
passenger_root /usr/local/lib/nginx-builder/passenger;
passenger_data_buffer_dir /var/lib/nginx/tmp/passenger;
passenger_ruby /usr/bin/ruby;
passenger_instance_registry_dir /var/run/passenger-instreg;
passenger_python /usr/bin/python3;
passenger_nodejs /usr/bin/node;
passenger_friendly_error_pages on;
passenger_disable_security_update_check on;
passenger_disable_anonymous_telemetry on;
passenger_log_file /var/log/nginx/passenger.log;
passenger_min_instances 0;
passenger_max_pool_size 32;
passenger_pool_idle_time 18000;
passenger_max_instances_per_app 1;
EOF

[[ "$OS" == "ubuntu" ]] && sed -i "s|/tmp/passenger|/passenger|g" /etc/nginx/passenger.conf

cat <<'EOF' > /etc/nginx/proxy.conf
proxy_set_header Upgrade           $http_upgrade;
proxy_set_header Connection        "upgrade";
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host  $host;
proxy_set_header X-Forwarded-Port  $server_port;
proxy_request_buffering off;
EOF

cat <<'EOF' > /etc/nginx/finetuning.conf
server_names_hash_bucket_size 128;
server_names_hash_max_size 131072;
limit_req_status 429;
limit_req zone=basic_limit burst=6000 nodelay;
limit_req_zone $server_name zone=basic_limit:50m rate=100r/s;
gzip_types application/atom+xml application/javascript application/json application/rss+xml
           application/vnd.ms-fontobject application/x-font-opentype application/x-font-ttf
           image/svg+xml image/x-icon image/x-ms-bmp text/css text/plain text/xml;
gzip_min_length 256;
gzip_comp_level 3;
gzip on;
sendfile on;
aio threads;
directio 16m;
tcp_nopush on;
keepalive_timeout 60;
keepalive_requests 1000;
output_buffers 3 512k;
client_body_buffer_size 256k;
client_max_body_size 512m;
disable_symlinks if_not_owner;
proxy_http_version 1.1;
ssl_protocols TLSv1.2 TLSv1.3;
server_tokens off;
merge_slashes off;
msie_padding off;
quic_gso on;
quic_retry on;
ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:16m;
ssl_session_timeout 1h;
ssl_session_tickets off;
ssl_early_data on;
ssl_buffer_size 8k;
EOF

cat <<'EOF' > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
worker_rlimit_nofile 65535;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;
events {
    worker_connections 10240;
}
http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    include /etc/nginx/mime.types;
    include /etc/nginx/finetuning.conf;
    include /etc/nginx/fastcgi.conf;
    include /etc/nginx/proxy.conf;
    include /etc/nginx/passenger.conf;
    default_type application/octet-stream;
    map $sent_http_content_type $expires {
        default off;
        text/html epoch;
        text/css 7d;
        application/javascript 7d;
        ~image/ 7d;
        ~font/ 7d;
        ~audio/ 7d;
        ~video/ 7d;
    }
    expires $expires;
    server {
        server_name _;
        listen 80;
        listen [::]:80;
        return 301 https://$host$request_uri;
    }
    server {
        server_name _;
        listen 443 quic reuseport;
        listen [::]:443 quic reuseport;
        listen 443 ssl;
        listen [::]:443 ssl;

        ssl_certificate /etc/ssl/default/cert.pem;
        ssl_certificate_key /etc/ssl/default/key.pem;

        location / {
            root /usr/local/share/www;
            index nosite.html;
            try_files $uri /nosite.html;
        }
    }
    include /etc/nginx/conf.d/*.conf;
}
EOF

[[ "$OS" == "ubuntu" ]] && sed -i "s/conf.d/sites-enabled/g" /etc/nginx/nginx.conf

cat <<'EOF' > /etc/nginx/mime.types
types {
    text/html                                        html htm shtml;
    text/css                                         css;
    application/xml                                  xml;
    image/gif                                        gif;
    image/jpeg                                       jpeg jpg;
    application/javascript                           js;
    application/atom+xml                             atom;
    application/rss+xml                              rss;

    text/mathml                                      mml;
    text/plain                                       txt;
    text/vnd.sun.j2me.app-descriptor                 jad;
    text/vnd.wap.wml                                 wml;
    text/x-component                                 htc;

    image/avif                                       avif;
    image/png                                        png;
    image/svg+xml                                    svg svgz;
    image/tiff                                       tif tiff;
    image/vnd.wap.wbmp                               wbmp;
    image/webp                                       webp;
    image/x-icon                                     ico;
    image/x-jng                                      jng;
    image/x-ms-bmp                                   bmp;

    font/woff                                        woff;
    font/woff2                                       woff2;
    application/x-font-ttf                           ttf;
    application/x-font-opentype                      otf;

    application/java-archive                         jar war ear;
    application/json                                 json;
    application/mac-binhex40                         hqx;
    application/msword                               doc;
    application/pdf                                  pdf;
    application/postscript                           ps eps ai;
    application/rtf                                  rtf;
    application/vnd.apple.mpegurl                    m3u8;
    application/vnd.google-earth.kml+xml             kml;
    application/vnd.google-earth.kmz                 kmz;
    application/vnd.ms-excel                         xls;
    application/vnd.ms-fontobject                    eot;
    application/vnd.ms-powerpoint                    ppt;
    application/vnd.oasis.opendocument.graphics      odg;
    application/vnd.oasis.opendocument.presentation  odp;
    application/vnd.oasis.opendocument.spreadsheet   ods;
    application/vnd.oasis.opendocument.text          odt;
    application/vnd.openxmlformats-officedocument.presentationml.presentation
                                                     pptx;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
                                                     xlsx;
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
                                                     docx;
    application/vnd.wap.wmlc                         wmlc;
    application/wasm                                 wasm;
    application/x-7z-compressed                      7z;
    application/x-cocoa                              cco;
    application/x-java-archive-diff                  jardiff;
    application/x-java-jnlp-file                     jnlp;
    application/x-makeself                           run;
    application/x-perl                               pl pm;
    application/x-pilot                              prc pdb;
    application/x-rar-compressed                     rar;
    application/x-redhat-package-manager             rpm;
    application/x-sea                                sea;
    application/x-shockwave-flash                    swf;
    application/x-stuffit                            sit;
    application/x-tcl                                tcl tk;
    application/x-x509-ca-cert                       der pem crt;
    application/x-xpinstall                          xpi;
    application/xhtml+xml                            xhtml;
    application/xspf+xml                             xspf;
    application/zip                                  zip;

    application/octet-stream                         bin exe dll;
    application/octet-stream                         deb;
    application/octet-stream                         dmg;
    application/octet-stream                         iso img;
    application/octet-stream                         msi msp msm;

    audio/midi                                       mid midi kar;
    audio/mpeg                                       mp3;
    audio/ogg                                        ogg;
    audio/x-m4a                                      m4a;
    audio/x-realaudio                                ra;

    video/3gpp                                       3gpp 3gp;
    video/mp2t                                       ts;
    video/mp4                                        mp4;
    video/mpeg                                       mpeg mpg;
    video/quicktime                                  mov;
    video/webm                                       webm;
    video/x-flv                                      flv;
    video/x-m4v                                      m4v;
    video/x-mng                                      mng;
    video/x-ms-asf                                   asx asf;
    video/x-ms-wmv                                   wmv;
    video/x-msvideo                                  avi;
}
EOF


cat <<'EOF' > /etc/logrotate.d/nginx
/var/log/nginx/*.log /var/log/virtualmin/*_log {
    create 0640 nginx root
    daily
    rotate 10
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
	/bin/kill -USR1 `cat /run/nginx.pid 2>/dev/null` 2>/dev/null || true
    endscript
}
EOF

cat <<'EOF' > /etc/fail2ban/filter.d/ratelimit.conf
[Definition]
failregex = ^.+ \[error\] .+limiting requests, excess: \d+.\d+ by zone "\w+", client: <HOST>, .+$

ignoreregex =
EOF

cat <<'EOF' > /etc/fail2ban/filter.d/php.conf
[Definition]
failregex = ^<HOST> .* "POST \/+xmlrpc.php .* [24]\d+ \d* ".*"$
            ^<HOST> .* "POST \/+wp-login.php .* [24]\d+ \d* ".*"$
            ^<HOST> .* "GET \/index\.php\S+\/index\.php\S+ .* [24]\d+ \d* ".*"$

ignoreregex =
EOF


cat <<'EOF' > /etc/fail2ban/jail.local
[DEFAULT]
maxretry = 10
bantime = 86400 ; 24h
ignoreip = 127.0.0.1/8 ::1
banaction = nftables-multiport
banaction_allports = nftables-allports 

[sshd]
enabled = true
port    = ssh

[webmin-auth]
port    = 2443
enabled = true

[phpmyadmin-syslog]
enabled = true

[mysqld-auth]
enabled = true

[ratelimit]
enabled = true
port = http,https
logpath = /var/log/virtualmin/*error_log

[php]
enabled = true
port = http,https
logpath = /var/log/virtualmin/*access_log
EOF

cat <<'EOF' > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	set whitelist {
		type ipv4_addr
		size 65536
	}

	set whitelist-v6 {
		type ipv6_addr
		size 65536
	}

	chain INPUT {
		type filter hook input priority filter; policy accept;
		ct state established,related accept
		ip protocol icmp limit rate 4/second accept
		ip6 nexthdr ipv6-icmp limit rate 4/second accept
		ip protocol igmp limit rate 4/second accept
		iifname lo accept

		tcp dport { 22, 53, 80, 443, 3306, 5432, 2443-2453, 32000-65535 } counter accept
		udp dport { 53, 67, 68, 443, 546, 547, 32000-65535 } counter accept
		tcp sport 53 counter accept
		udp sport 53 counter accept
		counter reject with icmp type host-prohibited
		counter reject with icmpv6 type admin-prohibited
	}

	chain OUTPUT {
		type filter hook output priority 0; policy accept;
		oifname lo counter accept
		ct state established accept
		tcp sport { 22, 53 } counter accept
		tcp dport { 22, 53 } counter accept
		udp sport { 53, 67, 68, 546, 547 } counter accept
		udp dport { 53, 67, 68, 546, 547 } counter accept
		tcp dport 25 counter reject
		ip daddr @whitelist accept
		ip6 daddr @whitelist-v6 accept
	}

	chain FORWARD {
		type filter hook forward priority 0; policy drop;
	}

	chain WHITELIST-SET {
	}
}

include "/etc/nftables-docker.conf"
include "/etc/nftables-whitelist.conf"
include "/etc/nftables-firewall.conf"
add rule inet filter OUTPUT jump WHITELIST-SET
EOF

# https://gist.github.com/goll/bdd6b43c2023f82d15729e9b0067de60
cat <<'EOF' > /etc/nftables-docker.conf
#!/usr/sbin/nft -f

table ip filter {
	chain INPUT {
		type filter hook input priority 0; policy accept;
	}

	chain FORWARD {
		type filter hook forward priority 0; policy accept;
		counter jump DOCKER-USER
		counter jump DOCKER-ISOLATION-STAGE-1
		oifname "docker0" ct state established,related counter accept
		oifname "docker0" counter jump DOCKER
		iifname "docker0" oifname != "docker0" counter accept
		iifname "docker0" oifname "docker0" counter accept
	}

	chain OUTPUT {
		type filter hook output priority 0; policy accept;
	}

	chain DOCKER {
	}

	chain DOCKER-ISOLATION-STAGE-1 {
		iifname "docker0" oifname != "docker0" counter jump DOCKER-ISOLATION-STAGE-2
		counter return
	}

	chain DOCKER-ISOLATION-STAGE-2 {
		oifname "docker0" counter drop
		counter return
	}

	chain DOCKER-USER {
		counter return
	}
}
table ip nat {
	chain PREROUTING {
		type nat hook prerouting priority -100; policy accept;
		fib daddr type local counter jump DOCKER
	}

	chain INPUT {
		type nat hook input priority 100; policy accept;
	}

	chain POSTROUTING {
		type nat hook postrouting priority 100; policy accept;
		oifname != "docker0" ip saddr 172.17.0.0/16 counter masquerade
	}

	chain OUTPUT {
		type nat hook output priority -100; policy accept;
		ip daddr != 127.0.0.0/8 fib daddr type local counter jump DOCKER
	}

	chain DOCKER {
		iifname "docker0" counter return
	}
}
EOF

if [ ! -f /etc/nftables-whitelist.conf ]; then
  cat <<'EOF' > /etc/nftables-whitelist.conf
#!/usr/sbin/nft -f

flush set inet filter whitelist
# add element inet filter whitelist { x.x.x.x }
# add element inet filter whitelist-v6 { x:x:x::x:x }
EOF
fi
if [ ! -f /etc/nftables-firewall.conf ]; then
  cat <<'EOF' > /etc/nftables-firewall.conf
#!/usr/sbin/nft -f

flush chain inet filter WHITELIST-SET
# add rule inet filter WHITELIST-SET skuid <id> counter reject comment "<name>"
EOF
fi

if [[ "$OS" == "rocky" ]]; then
  cat <<'EOF' > /etc/sysconfig/nftables.conf
#!/usr/sbin/nft -f

include "/etc/nftables.conf"
EOF
fi

if [[ "$OS" == "rocky" ]]; then
  sed -i '/allow-query/d' /etc/named.conf
  sed -i '/allow-recursive/d' /etc/named.conf
  sed -i 's/recursion no/recursion yes/g' /etc/named.conf
fi
mkdir -p /etc/cloud && touch /etc/cloud/cloud-init.disabled

cat <<'EOF' > /etc/resolv.conf
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

crontab -u root -l || cat <<'EOF' | crontab -u root -
# Entry commented are safeguards implemented in DOM Cloud. You might not need them
# 0 * * * * find '/var/spool/cron/' -not -name root -type f | xargs sed -ri '/^\s*(\*|[0-9]*,)/d'
# */5 * * * * /usr/bin/node /home/bridge/public_html/sudokill.js -i bridge,do-agent,dbus,earlyoom,mysql,named,nobody,postgres,polkitd,rpc,valkey

*/5 * * * * /usr/local/lib/nginx-builder/cleanup.sh
@daily passenger-config reopen-logs
@weekly /usr/bin/node /home/bridge/public_html/sudocleanssl.js
@weekly find /var/spool/clientmqueue /var/webmin/diffs -mindepth 1 -delete
@weekly find /home -maxdepth 1 -type d -ctime +1 -exec rm -rf {}/{.cache,.npm,Downloads,public_html/.yarn/cache,public_html/node_modules/.cache,.composer/cache} \;
@weekly find /home -maxdepth 1 -type d -ctime +1 -exec rdfind -minsize 100000 -makehardlinks true -makeresultsfile false {}/{.vscode-server,.pyenv,.rvm,.cargo,.local,go,.rustup,public_html/node_modules} \;
@weekly /usr/bin/bash /home/bridge/public_html/src/whitelist/refresh.sh
@monthly find /etc/letsencrypt/{csr,keys} -name *.pem -type f -mtime +180 -exec rm -f {} ';'
EOF

# Bridge
if [ ! -e "/lib/systemd/system/bridge.service" ]; then
if [[ "$OS" == "ubuntu" ]]; then
  /usr/share/webmin/changepass.pl /etc/webmin root $PASSWD
else
  /usr/libexec/webmin/changepass.pl /etc/webmin root $PASSWD
fi
git clone https://github.com/domcloud/Virtualmin-Config
cd Virtualmin-Config && sh patch.sh && cd .. && rm -rf Virtualmin-Config
timeout 900 virtualmin config-system --bundle DomCloud
virtualmin create-domain --domain localhost --user bridge --pass $PASSWD --dir --unix --virtualmin-nginx --virtualmin-nginx-ssl
cat <<'EOF' | EDITOR='tee' visudo /etc/sudoers.d/bridge
bridge ALL = (root) NOPASSWD: /home/bridge/public_html/sudoutil.js
bridge ALL = (root) NOPASSWD: /bin/systemctl restart bridge
EOF
cat <<'EOF' > /lib/systemd/system/bridge.service
[Unit]
Description=DOM Cloud Bridge
Documentation=https://domcloud.co
After=network.target

[Service]
Type=simple
User=bridge
WorkingDirectory=/home/bridge/public_html
ExecStart=/usr/bin/node /home/bridge/public_html/app.js
TimeoutStopSec=5
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo -u bridge bash <<EOF
export PATH=/usr/local/bin:$PATH
cd ~
rm -rf public_html
git clone https://github.com/domcloud/bridge public_html
cd public_html
sh tools-init.sh
echo "SECRET=rocky" > .env
rm -rf ~/.cache ~/.npm ~/public_html/phpmyadmin/node_modules
EOF

systemctl daemon-reload
systemctl enable bridge --now

while ! curl -sS http://localhost:2223/status/about; do
    sleep 1
done
echo ""

curl -sSX POST \
  'http://localhost:2223/runner/?domain=localhost' \
  --header 'Accept: */*' \
  --header 'User-Agent: DOM Cloud' \
  --header 'Authorization: Bearer rocky' \
  --header 'Content-Type: application/json' \
  --data-raw '{
  "nginx": {
    "locations": [
      {
        "fastcgi": "on",
        "root": "public_html/",
        "passenger": {
          "enabled": "off"
        },
        "match": "/phpmyadmin/"
      },
      {
        "fastcgi": "on",
        "root": "public_html/",
        "passenger": {
          "enabled": "off"
        },
        "match": "/phppgadmin/"
      },
      {
        "fastcgi": "on",
        "root": "public_html/",
        "passenger": {
          "enabled": "off"
        },
        "match": "/phprdadmin/"
      },
      {
        "root": "public_html/webssh/webssh/static",
        "passenger": {
          "app_root": "public_html/webssh",
          "enabled": "on",
          "app_start_command": "python run.py --port=$PORT",
          "document_root": "public_html/webssh/webssh/static"
        },
        "rewrite": "^/webssh/(.*)$ /$1 break",
        "match": "/webssh/"
      },
      {
        "root": "public_html/webssh2/app/client/public",
        "passenger": {
          "app_root": "public_html/webssh2/app",
          "app_start_command": "env PORT=$PORT node app.js",
          "enabled": "on",
          "document_root": "public_html/webssh2/app/client/public"
        },
        "match": "/ssh/"
      },
      {
        "match": "^~ /.well-known/",
        "try_files": "$uri $uri/ =404"
      },
      {
        "match": "/",
        "proxy_pass": "http://127.0.0.1:2223"
      }],
      "fastcgi": "on",
      "index": "index.html index.php",
      "root": "public_html/public",
      "ssl": "on"
    }
  }'
fi

echo "wizard_run=1" >> /etc/webmin/virtual-server/config

# Sanity check
sysctl --system

df -h

sync

sleep 3

exit 0
