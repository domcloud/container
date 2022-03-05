#!/bin/bash

zunpack () {
if [ -z "$(ls -A $1)" ] ; then
    cp -a /tmp/artifacts$1/* $1/
fi
}

zunpack /etc/nginx
zunpack /etc/php
zunpack /etc/postgresql
zunpack /etc/mysql
zunpack /etc/ssh
zunpack /etc/webmin
zunpack /var/lib/mysql
zunpack /var/lib/postgresql

if [ ! -d /home/index ] ; then
    # init default domain
    printf "Installing index controller"
    virtualmin create-domain --user index --domain `hostname -f` --pass \
    `echo $RANDOM | md5sum | head -c 20` --unix --dir --webmin \
    --virtualmin-nginx-ssl --virtualmin-nginx
    if [ $? -eq 0 ]; then
        cd /home/index/public_html
        rm -rf *
        git clone https://github.com/domcloud/bridge .
        /bin/bash tools-init.sh
        echo 'index ALL = (root) NOPASSWD: `echo $PWD`/sudoutil.js' | sudo EDITOR='tee' visudo /etc/sudoers.d/index
        chmod -R 0750 .
        cd ~
    else
        echo Installing index controller failed
    fi
fi

/usr/bin/systemctl default --init