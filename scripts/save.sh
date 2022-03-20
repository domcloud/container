#!/bin/bash

# Save all artifacts to temporary directory
# So when we run, if one mount is empty,
# it will be filled from the artifact

save () {
  mkdir -p /tmp/artifacts$1
  cp -a $1/* /tmp/artifacts$1/
}

# save artifacts
save /etc
save /var/log
save /var/lib/mysql
save /var/lib/postgresql

# apply templates
cp -a /tmp/artifacts/templates/nginx.conf /etc/nginx/nginx.conf
