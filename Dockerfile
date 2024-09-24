# Dockerfile

FROM ubuntu:22.04

RUN apt-get update && \
apt-get install -y wget unzip qemu-kvm libvirt-clients libvirt-daemon-system \
bridge-utils virtinst dnf curl && \
rm -rf /var/lib/apt/lists/*

COPY . .

CMD ["bash", "./imgprep.sh"]
