#!/bin/bash
set -e
cd /root
export TERM=xterm-256color

apt-get update
curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup --verbose

apt-get install -y nginx-full webmin-virtualmin-nginx webmin-virtualmin-nginx-ssl

virtualmin-config-system -i Nginx
