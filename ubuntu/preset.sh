
sed -i 's/port=10000/port=2443/g' /etc/webmin/miniserv.conf


#init postgresql DB
PG=17
PGDATA=/usr/share/postgresql/$PG/data
sudo -u postgres /usr/lib/postgresql/$PG/bin/initdb -D $PGDATA || true
sed -i "s/#listen_addresses = .*/listen_addresses = '*'/g" $PGDATA/postgresql.conf
sed -i "s/max_connections = 100/max_connections = 4096/g" $PGDATA/postgresql.conf
cat <<'EOF' > $PGDATA/pg_hba.conf
local   all             all                                     peer
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
EOF

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
add_to=/etc/nginx/sites-available
stop_cmd=systemctl stop nginx
apply_cmd=systemctl reload nginx
child_procs=4
add_link=/etc/nginx/sites-enabled
start_cmd=systemctl start nginx
nginx_cmd=/usr/sbin/nginx
php_socket=1
nginx_config=/etc/nginx/nginx.conf
listen_mode=0
EOF

/usr/share/webmin/changepass.pl /etc/webmin root "rocky"
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