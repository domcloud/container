#!/bin/bash

zunpack () {
if [ -z "$(ls -A $1)" ] ; then
    cp -a /tmp/artifacts$1 $1/
fi
}

zunpack /etc/nginx
zunpack /etc/ssh
zunpack /etc/webmin
zunpack /var/lib/mysql
zunpack /home
zunpack /var/lib/pgsql/data
zunpack /var/named

/usr/bin/systemctl default --init