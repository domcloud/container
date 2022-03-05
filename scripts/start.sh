#!/bin/bash

zunpack () {
if [ -z "$(ls -A $1)" ] ; then
    cp -a /tmp/artifacts$1/* $1/
fi
}

zunpack /etc/nginx
zunpack /etc/ssh
zunpack /etc/webmin
zunpack /var/lib/mysql
zunpack /var/lib/postgresql/data
zunpack /etc/bind/zones

/usr/bin/systemctl default --init