#!/bin/bash

# Save all artifacts to temporary directory
# So when we run, if one mount is empty,
# it will be filled from the artifact

save () {
  mkdir -p /tmp/artifacts$1
  cp -a $1/* /tmp/artifacts$1/
}

# save artifacts
save /etc/nginx
save /etc/php
save /etc/ssh
save /etc/postgresql
save /etc/mysql
save /etc/webmin
save /var/lib/mysql
save /var/lib/postgresql

# apply templates
cp -a /tmp/artifacts/templates/nginx.conf /etc/nginx/nginx.conf
