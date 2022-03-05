#!/bin/bash

# Save all artifacts to temporary directory
# So when we run, if one mount is empty,
# it will be filled from the artifact

save () {
  mkdir -p /tmp/artifacts$1
  cp -a $1 /tmp/artifacts$1/
}

save /etc/nginx
save /etc/ssh
save /etc/webmin
save /var/lib/mysql
save /home
save /var/lib/psql/data
save /var/named
