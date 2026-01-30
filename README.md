# DOM Cloud Container

Set up your own DOM Cloud server instance inside a virtualized platform and control it with our cloud platform.

![](https://domcloud.co/assets/ss/selfhost.png)

Our self hosted solution is for our customers who:

+ Behind a corporate that mandates all data is self hosted to an on-premise server
+ Wishing for more computing power or having the hardware their your control

With Caveats:

+ This approach is generally more complex than simply using our cloud servers
+ Requires good knowledge of Linux and its networking components to make everything works
+ You're resposible to everything a server needs to do, including keeping the software up to date

Here's feature comparison:

| Compare Features | Cloud | Self-Hosted |
|:---|:---:|:---:|
| Getting Started  | Easy  | Easy but Challenging |
| Who own the Infra? | Us  | You |
| Who monitor Infra? | Us  | You |
| Has Public IP | ✅  | Depends on your ISP |
| Use `nsp/nss.domcloud.co` NS   | ✅ | ❌ |
| Can use `domcloud.dev` | ✅ | If not behind NAT |
| Storage/Network Limit  | Calculated  | Unlimited  |
| Can have `root` Access   | ❌ | ✅ |
| Self-hosted email  | ❌ | Possible [but discouraged](https://cfenollosa.com/blog/after-self-hosting-my-email-for-twenty-three-years-i-have-thrown-in-the-towel-the-oligopoly-has-won.html) |

## Installing 

Complete DOM Cloud services requires 2GB of RAM and 30GB of disk to work, more is recommended for production servers. 

You can run these from freshly installed [Rocky Linux Minimal ISO](https://rockylinux.org/download) or [Ubuntu Server ISO](https://ubuntu.com/download/server) instead:

```sh
export OPTIONAL_INSTALL=1
# make sure to run this using root:
if [ -f /etc/lsb-release ]; then OS=ubuntu; elif [ -f /etc/debian_version ]; then OS=debian; elif [ -f /etc/redhat-release ]; then OS=rocky; else OS=unknown; fi
curl -sSL https://raw.githubusercontent.com/domcloud/container/refs/heads/master/install-$OS.sh | bash
curl -sSL https://raw.githubusercontent.com/domcloud/container/refs/heads/master/install-extra.sh | bash
curl -sSL https://raw.githubusercontent.com/domcloud/container/refs/heads/master/preset.sh | bash
# Then change passwords (save and remember the passwords generated)
curl -sSL https://raw.githubusercontent.com/domcloud/container/refs/heads/master/genpass.sh | bash
```

Or if you want to make changes as well

```sh
export OPTIONAL_INSTALL=1
# make sure to run this using root:
if [ -f /etc/lsb-release ]; then OS=ubuntu; elif [ -f /etc/debian_version ]; then OS=debian; elif [ -f /etc/redhat-release ]; then OS=rocky; else OS=unknown; fi
git clone https://github.com/domcloud/container && cd container
./install-$OS.sh
./install-extra.sh
./preset.sh
# Then change passwords (save and remember the passwords generated)
./genpass.sh
```


More information about installing and integrating this to DOM Cloud Portal can be read [in the documentation](https://domcloud.co/docs/intro/self-hosting).

## Building disk image

We use [Hashicorp Packer](https://developer.hashicorp.com/packer/docs/install) to build images. We ran it inside privilenged docker. Simply run `make build-image`. With KVM acceleration the build should be done around one hour.

The image consist of [Rocky Linux Minimal ISO](https://rockylinux.org/download) + Some scripts that installs Virtualmin and additional services to make it exactly like how a DOM Cloud server works.

To run the final image using [QEMU](https://www.qemu.org):

```bash
qemu-system-x86_64 -hda domcloud-x86_64.qcow2 -smp 2 -m 2048 -net nic -net user,hostfwd=tcp::2022-:22,hostfwd=tcp::2080-:80,hostfwd=tcp::3443-:443,hostfwd=tcp::2443-:2443 -cpu max -accel kvm
# Windows: -cpu Broadwell -accel whpx,kernel-irqchip=off
```

This VM expose these ports:

+ 22 for SSH
+ 53 for DNS
+ 80 and 443 for HTTP/HTTPS
+ 2443 for Webmin

There's `http://localhost` Handled by NGINX to that runs our [bridge](https://github.com/domcloud/bridge/) software. This software orchestrates your VM based on (To be undocumented) REST APIs.

Go to `https://localhost:2443` in your browser to open webmin. Additionally, go to `http://localhost/status/check` and  `http://localhost/status/test` To see if all services running and configured correctly.

Enter credential `root` with `rocky` as password for SSH and Webmin login. 

The root password includes the `root` webmin access is `rocky`. The `bridge` HTTP secret and webmin login is also set to `rocky`.

## Things to do after your VM Running

Most post installation steps [is already documented](https://domcloud.co/docs/intro/self-hosting#post-installation). Here are the rest specific for building from image disks.

### Install the correct IPv4 and IPv6 addresses

The VM is built with QEMU. The networking IP addresses definitely changed and you need to adjust it.

1. Identify your IP addresses, run `nmcli dev show ens3` or `ip addr show scope global` in terminal.
2. Go to `Virtualmin` -> `Addresses and Networking` -> `Change IP Addresses`
3. Enter old IP `10.0.2.15` and new IP. Click `Change Now`.
4. Also Update DNS default IP address by go to `Virtualmin Configuration` -> `Networking Settings` -> Default IP Address for DNS records.

### Rename Bridge's `localhost` domain

The bridge default domain name is defaulted to `localhost` so you can open it via your laptop. But to connect it to DOM Cloud, you must put it to a domain. You can run this in SSH:

```sh
virtualmin change-domain --username bridge --new-domain mysystemdomain.com
```

Make sure to insert A or AAAA record to that domain.

### Get SSL for the Bridge's Domain

First, change your system hostname to the domain

```sh
sudo hostnamectl set-hostname "mysystemdomain.com"
```

Then [read more in the separate documentation](https://domcloud.co/docs/intro/self-hosting#assign-to-a-domain)

### Expand Disk (Rocky / XFS)

The disk is prebuilt with capped at 40 GB. Here's how it layouted.

```
# lsblk
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                 11:0    1 1024M  0 rom
vda                252:0    0  256G  0 disk
├─vda1             252:1    0    1G  0 part /boot
└─vda2             252:2    0   39G  0 part
  ├─rl_rocky9-root 253:0    0 36.9G  0 lvm  /
  └─rl_rocky9-swap 253:1    0    2G  0 lvm  [SWAP]
```

The `vda` is the real disk provisioned by the system. To extend the `vda2`: 

2. Open `parted /dev/vda`
    + `resizepart`
    + Select 2 `vda2`
    + Enter the new size `100%`
3. `partprobe`
4. `pvresize /dev/vda2`
5. Resize swap
    + Turn off the swap `swapoff /dev/mapper/rl_rocky9-swap`
    + Extend it (say 8GB) `lvresize -L 8G /dev/rl_rocky9/swap`
    + `mkswap /dev/rl_rocky9/swap`
    + `swapon /dev/rl_rocky9/swap`
6. Resize main disk
    + `lvresize -l +100%FREE /dev/rl_rocky9/root`
    + `xfs_growfs /`

## Connect to DOM Cloud

Goto `Servers` section in [DOM Cloud Portal Dashboard](https://my.domcloud.co) to connect to our cloud portal.

Why still connecting to our cloud portal?

+ Bridge is `headless`. There are no UI, just pure APIs. The APIs are used to communicate to your instance.
+ All tools works out of the box, including Deployment systems, templates and GitHub integration
+ Deployments for self-hosted instances doesn't use storage/data network/instance limit
+ You get some cloud features like backups, domcloud.dev domain, team collab, etc
+ Can be connected for free

## More Post Installation Checklist

1. Check /home has been mounted properly
2. Check SELinux disabled
3. Check quota root and home working
4. Check DNS IP correct
5. Check IPv6 working
6. Check DNS Slave servers
7. Check S3 Backups
8. Check Root password
9. Check SSH login by password enabled
10. Check bridge envars
11. Create SSL_WILDCARDS domains and setup sync:

```sh
mkdir -p ~/.ssh
SHARED_DOMAIN_OWNER=sga.domcloud.co
cat <<EOF > .ssh/config
Host $SHARED_DOMAIN_OWNER
        StrictHostKeyChecking no
        IdentityFile ~/.ssh/$SHARED_DOMAIN_OWNER
EOF
cat <<EOF | crontab -
1 0 1 * * scp '$USER@$SHARED_DOMAIN_OWNER:$HOME/*' $HOME/
EOF
```
