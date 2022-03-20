#!/bin/bash

zunpack () {
if [ -z "$(ls -A $1)" ] ; then
    cp -a /tmp/artifacts$1/* $1/
fi
}

zunpack /etc
zunpack /var/lib/mysql
zunpack /var/lib/postgresql

/usr/bin/systemctl default --init &
mainpid=$!

echo DEBUG Start
echo Systemctl is $mainpid
ls /usr/share/webmin/virtual-server/create-domain.pl

sleep 20 # wait for all services ON

if [ ! -d /home/index ] ; then
    # init default domain
    printf "Installing index controller"
    virtualmin create-domain --user index --domain `hostname -f` --pass \
    `echo $RANDOM | md5sum | head -c 20` --unix --dir --webmin \
    --virtualmin-nginx-ssl --virtualmin-nginx
    if [ $? -eq 0 ]; then
        sleep 1
        virtualmin modify-web --domain `hostname -f` --document-dir public_html/public
        cd /home/index/public_html
        rm -rf *
        git clone https://github.com/domcloud/bridge .
        /bin/bash tools-init.sh
        echo 'index ALL = (root) NOPASSWD: `echo $PWD`/sudoutil.js' | EDITOR='tee' visudo /etc/sudoers.d/index
        chmod -R 0750 .
        cd ~
    else
        echo Installing index controller failed
    fi
fi

wait $mainpid
