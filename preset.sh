
# Contents
wget -O /usr/local/bin/restart https://raw.githubusercontent.com/domcloud/bridge/main/userkill.sh && chmod 755 /usr/local/bin/restart
WWW=/usr/local/share/www && WWWSOURCE=https://raw.githubusercontent.com/domcloud/domcloud/master/share && mkdir -p $WWW
wget -O $WWW/deceptive.html $WWWSOURCE/deceptive.html
wget -O $WWW/nosite.html $WWWSOURCE/nosite.html
chmod 0755 -R $WWW

SKEL=/etc/skel/public_html
mkdir -p $SKEL/.well-known && touch $SKEL/favicon.ico
wget -O $SKEL/index.html $WWWSOURCE/index.html

mkdir -p /etc/ssl/default/
wget https://raw.githubusercontent.com/willnode/forward-domain/refs/heads/main/test/certs/localhost/key.pem -P /etc/ssl/default/
wget https://raw.githubusercontent.com/willnode/forward-domain/refs/heads/main/test/certs/localhost/cert.pem -P /etc/ssl/default/


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
@nginx           hard    as              2048000
@nginx           hard    nproc           64
@nginx           hard    priority        5
EOF
mkdir -p /etc/systemd/system/{nginx,earlyoom,iptables,ip6tables}.service.d
cat <<'EOF' > /etc/systemd/system/nginx.service.d/override.conf
[Service]
LimitNOFILE=65535
EOF
cat <<'EOF' > /etc/systemd/system/earlyoom.service.d/override.conf
[Service]
SupplementaryGroups=adm
EOF
cat <<'EOF' > /etc/systemd/system/iptables.service.d/override.conf
[Service]
ExecStartPre=sh -c "ipset restore -! < /etc/ipset"
EOF
cat <<'EOF' > /etc/systemd/system/ip6tables.service.d/override.conf
[Service]
ExecStartPre=sh -c "ipset restore -! < /etc/ipset6"
EOF
mkdir -p /etc/systemd/system/user.slice.d
cat <<'EOF' > /etc/systemd/system/user.slice.d/50-cpu-limit.conf
[Slice]
CPUAccounting=yes
CPUQuota=70%
EOF


# DB
cat <<'EOF' > /etc/my.cnf.d/mariadb-server.cnf
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mariadb/mariadb.log
pid-file=/run/mariadb/mariadb.pid
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
systemctl start mariadb # init db

PG=17
PGDATA=/var/lib/pgsql/$PG/data
sudo -u postgres /usr/pgsql-$PG/bin/initdb -D $PGDATA
sed -i "s/#listen_addresses = .*/listen_addresses = '*'/g" $PGDATA/postgresql.conf
sed -i "s/max_connections = 100/max_connections = 4096/g" $PGDATA/postgresql.conf
cat <<'EOF' > $PGDATA/pg_hba.conf
local   all             all                                     peer
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
EOF

sed -i 's/port=10000/port=2443/g' /etc/webmin/miniserv.conf

cat <<'EOF' | while read -r line; do
allow_subdoms=0
auto_letsencrypt=0
avail_xterm=1
aws_cmd=aws
bind_spf=
bind_sub=yes
bw_active=1
bw_owner=0
cert_type=sha1
collect_noall=1
collect_interval=60
combined_cert=2
disable=web,mysql,postgres
dns_ip=10.0.2.15
dns_records=@
dovecot_ssl=0
hard_quotas=0
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
passwd_mode=0
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

cat <<EOF > /etc/webmin/webmincron/crons/1732240335203271.cron
mins=17
active=1
months=*
days=*
module=virtual-server
id=1732240335203271
func=run_cron_script
arg0=collectinfo.pl
weekdays=*
hours=*
user=root
special=
interval= 
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
hba_conf=$PGDATA/pg_hba.conf
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

cat <<'EOF' > /etc/webmin/virtualmin-nginx/config
php_socket=1
nginx_cmd=/usr/sbin/nginx
add_to=/etc/nginx/conf.d
http2=0
listen_mode=0
child_procs=4
extra_dirs=
rotate_cmd=nginx -s reload
apply_cmd=systemctl reload nginx
stop_cmd=systemctl stop nginx
start_cmd=systemctl start nginx
add_link=
nginx_config=/etc/nginx/nginx.conf
EOF


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
fastcgi_param PATH_INFO $fastcgi_path_info;
fastcgi_param HTTPS $https;
fastcgi_split_path_info ^(.+\.php)(/.+)$;
fastcgi_read_timeout 600s;
EOF

cat <<'EOF' > /etc/nginx/passenger.conf
passenger_root /usr/local/lib/nginx-builder/passenger;
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

cat <<'EOF' > /etc/sysconfig/iptables
*filter
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m multiport --dports 22,80,443,3306,5432 -j ACCEPT
-A INPUT -p tcp -m multiport --dports 2443:2453,32000:65535 -j ACCEPT
-A INPUT -p udp -m multiport --dports 67,68,443 -j ACCEPT
-A INPUT -p tcp -m multiport --ports 53 -j ACCEPT
-A INPUT -p udp -m multiport --ports 53 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
-A OUTPUT -o lo -j ACCEPT
-A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
-A OUTPUT -p tcp -m multiport --dports 22,53 -j ACCEPT
-A OUTPUT -p udp -m multiport --dports 67,68 -j ACCEPT
-A OUTPUT -p tcp -m multiport --ports 53 -j ACCEPT
-A OUTPUT -p udp -m multiport --ports 53 -j ACCEPT
-A OUTPUT -p tcp -m tcp --dport 25 -j REJECT
-A OUTPUT -m set --match-set whitelist dst -j ACCEPT
COMMIT
EOF

cat <<'EOF' > /etc/sysconfig/ip6tables
*filter
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
-A INPUT -p ipv6-icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m multiport --dports 22,80,443,3306,5432 -j ACCEPT
-A INPUT -p tcp -m multiport --dports 2443:2453,32000:65535 -j ACCEPT
-A INPUT -p udp -m multiport --dports 443,546,547 -j ACCEPT
-A INPUT -p tcp -m multiport --ports 53 -j ACCEPT
-A INPUT -p udp -m multiport --ports 53 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp6-adm-prohibited
-A FORWARD -j REJECT --reject-with icmp6-adm-prohibited
-A OUTPUT -o lo -j ACCEPT
-A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
-A OUTPUT -p tcp -m multiport --dports 22,53 -j ACCEPT
-A OUTPUT -p udp -m multiport --dports 546,547 -j ACCEPT
-A OUTPUT -p tcp -m multiport --ports 53 -j ACCEPT
-A OUTPUT -p udp -m multiport --ports 53 -j ACCEPT
-A OUTPUT -p tcp -m tcp --dport 25 -j REJECT
-A OUTPUT -m set --match-set whitelist-v6 dst -j ACCEPT
COMMIT
EOF

ipset create whitelist hash:ip
ipset create whitelist-v6 hash:ip family inet6
ipset save whitelist > /etc/ipset
ipset save whitelist-v6 > /etc/ipset6

sed -i '/allow-query/d' /etc/named.conf
sed -i '/allow-recursive/d' /etc/named.conf
sed -i 's/recursion no/recursion yes/g' /etc/named.conf
mkdir -p /etc/cloud && touch /etc/cloud/cloud-init.disabled
cat <<'EOF' > /etc/resolv.conf
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

cat <<'EOF' > /var/spool/cron/root
# Entry commented are safeguards implemented in DOM Cloud. You might not need them
# 0 * * * * find '/var/spool/cron/' -not -name root -type f | xargs sed -i '/^\s*(\*|\d+,)/d'
# */5 * * * * /usr/bin/node /home/bridge/public_html/sudokill.js -i bridge,do-agent,dbus,earlyoom,mysql,named,nobody,postgres,polkitd,rpc

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
/usr/libexec/webmin/changepass.pl /etc/webmin root "rocky"
git clone https://github.com/domcloud/Virtualmin-Config
cd Virtualmin-Config && sh patch.sh && cd .. && rm -rf Virtualmin-Config
timeout 900 virtualmin config-system --bundle DomCloud
virtualmin create-domain --domain localhost --user bridge --pass "rocky" --dir --unix --virtualmin-nginx --virtualmin-nginx-ssl
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

sleep 3

curl -X POST \
  'http://localhost:2223/nginx/?domain=localhost' \
  --header 'Accept: */*' \
  --header 'User-Agent: DOM Cloud' \
  --header 'Authorization: Bearer rocky' \
  --header 'Content-Type: application/json' \
  --data-raw '{
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
      "match": "/",
      "proxy_pass": "http://127.0.0.1:2223"
    }
  ],
  "fastcgi": "on",
  "index": "index.html index.php",
  "root": "public_html/public",
  "ssl": "on"
}'

echo "wizard_run=1" >> /etc/webmin/virtual-server/config

# Sanity check
cat /etc/passwd
df -h

sync

sleep 3

exit 0
