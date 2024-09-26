# DOM Cloud Container

Set up your own DOM Cloud server instance inside a virtualized platform and control it with our platform.

![](https://domcloud.co/assets/ss/selfhost.png)

## Built Images

The most recent one built on 2024-09-26:

+ [domcloud-x86_64.qcow2](https://domcloud-images.fra1.cdn.digitaloceanspaces.com/2409/domcloud-x86_64.qcow2) 4.41 GB
+ [domcloud-x86_64.vmdx](https://domcloud-images.fra1.cdn.digitaloceanspaces.com/2409/domcloud-x86_64.vmdx) 2.84 GB
+ [checksum](https://domcloud-images.fra1.cdn.digitaloceanspaces.com/2409/checksums.txt)

Select based on Virtualization platform e.g. Proxmox and QEMU uses `QCOW2` while VMWare and VirtualBox uses `VMDK`. `aarch64` builds is not available yet.

## About the image

We use [Hashicorp Packer](https://developer.hashicorp.com/packer/docs/install) to build images. We ran it inside privilenged docker. Simply run `make build-image`. With KVM acceleration the build should be done around one hour.

The image consist of Rocky Linux Minimal CD + Some scripts that installs Virtualmin and additional services to make it exactly like how a DOM Cloud server works. See [install.sh](./install.sh) and [preset.sh](./preset.sh) to see the install scripts.

To run the final image using [QEMU](https://www.qemu.org):

```bash
qemu-system-x86_64 -hda domcloud-x86_64.qcow2 -smp 2 -m 2048 -net nic -net user,hostfwd=tcp::22-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::2443-:2443 -cpu max -accel tcg
```

This VM expose these ports:

+ 22 for SSH
+ 53 for DNS
+ 80 and 443 for HTTP/HTTPS
+ 2443 for Webmin

There's `http://localhost` Handled by NGINX to that runs our [bridge](https://github.com/domcloud/bridge/) software. This sorftware orchestrates your VM based on (To be undocumented) REST APIs.

Go to `https://localhost:2443` in your browser to open webmin. Additionally, go to `http://localhost/status/check` and  `http://localhost/status/test` To see if all services running and configured correctly.

The root password includes the `root` webmin access is `rocky`. The `bridge` HTTP secret and webmin login is also set to `rocky`.

Things to do after your VM online:

### Change your VM passwords

> [!IMPORTANT]  
> **Change your VM password to very strong one before exposing it to the public.**

You have 4 passwords to change:

1. Root password, change it with `passwd`
2. Webmin root password, change it with `/usr/libexec/webmin/changepass.pl /etc/webmin root "<password>"`
3. User `bridge` password, change it with `passwd bridge`
4. `bridge` HTTP Secret key, change it in `/home/bridge/public_html/.env` and restart it `sudo systemctl restart bridge`.

Additionally:
1. Disable root password auth via SSH by setting `PermitRootLogin prohibit-password` in `/etc/ssh/sshd_config`

### Check Virtualmin Configuration

Go to `https://localhost:2443` and log in with user `root`. 

1. Finish the post installation wizard
2. Go to `Virtualmin` -> `System Settings` -> `Re-Check Configuration`

### Install the correct IPv4 and IPv6 addresses

The VM is built with QEMU. The networking IP addresses definitely changed and you need to adjust it.

1. Identify your IP addresses, run `nmcli dev show ens3` or `ip addr show scope global` in terminal.
2. Go to `Virtualmin` -> `Addresses and Networking` -> `Change IP Addresses`
3. Enter old IP `10.0.2.15` and new IP. Click `Change Now`.

### Update Packages

Run `yum update`.

## Connect to DOM Cloud

Contact us to connect your instance to DOM Cloud.
