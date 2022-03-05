#!/bin/bash

# Save all artifacts to temporary directory
# So when we run, if one mount is empty,
# it will be filled from the artifact

save () {
  mkdir -p /tmp/artifacts$1
  cp -a $1 /tmp/artifacts$1/
}

save /usr/local/conf
save /etc/ssh
save /etc/webmin
save /etc/sysconfig
save /var/lib/mysql
save /home
save /var/lib/postgresql/data
save /var/named
