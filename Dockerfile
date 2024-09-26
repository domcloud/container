# Dockerfile

FROM ubuntu:22.04

RUN apt-get update && \
apt-get install -y wget unzip qemu-system-x86 qemu-system-arm libvirt-clients libvirt-daemon-system \
bridge-utils virtinst dnf curl libguestfs-tools linux-image-generic && \
rm -rf /var/lib/apt/lists/*

RUN PACKER=packer_1.10.3_linux_$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" ) && \
curl -fsSL https://releases.hashicorp.com/packer/1.10.3/$PACKER.zip -o /tmp/packer.zip && \
unzip /tmp/packer.zip -d /usr/local/bin && \
rm /tmp/packer.zip

WORKDIR /app

COPY . .

CMD ["bash", "./imgprep.sh"]
