curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup --verbose

apt-get update

apt-get install -y webmin webmin-virtual-server webmin-virtualmin-{nginx,nginx-ssl} virtualmin-config

