#!/bin/bash

zunpack () {
if [ -z "$(ls -A $1)" ] ; then
    cp -a /tmp/artifacts$1 $1/
fi
}

zunpack /usr/local/conf
zunpack /etc/ssh
zunpack /etc/webmin
zunpack /etc/sysconfig
zunpack /var/lib/mysql
zunpack /home
zunpack /var/lib/postgresql/data
zunpack /var/named

/usr/bin/systemctl default --init