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

if [ -z "$(ls -A /home)" ] ; then
    # init default domain
    printf "Installing index controller"
    virtualmin create-domain --user index --domain `hostname -f` --password \
    `echo $RANDOM | md5sum | head -c 20` --unix --dir --webmin \
    --virtualmin-nginx-ssl --virtualmin-nginx \
    cd /home/index/public_html
    rm -rf *
    git clone https://github.com/domcloud/bridge .
    /bin/bash tools-init.sh
    echo 'index ALL = (root) NOPASSWD: `echo $PWD`/sudoutil.js' | sudo EDITOR='tee' visudo /etc/sudoers.d/index
    chmod -r 0750 .
    cd ~
fi

/usr/bin/systemctl default --init