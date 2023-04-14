# DOM Cloud Container

Set up your own DOM Cloud server instance and control it with our platform.

This is a docker container. You need to install Docker on your machine to run this container.

System requirements to run this container:
+ Docker
+ 512MB+ of free memory
+ 2GB+ of free disk space
+ Fast internet connection

## Quickstart

```
cp .env.example .env
docker compose up
```

The first build might take around 15 minutes on cloud servers. The final image build will uccopy close to 2 GB of storage.

All website data are exported to volumes under `./mount`.

If your server is running with `systemd-resolved` service enabled, disable it first and add proper DNS servers to `/etc/resolv.conf`.

```bash
systemctl disable systemd-resolved
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
```

if you use this in production, prefer use `docker-compose -f compose-prod up`, it will use `network_mode: host`, enable IPv6 support, and activate disk quotas. To be able to do that your host system must be `linux/amd64` and using existing filesystem which has quota turned on (`usrquota`, `grpquota`).

### Options

+ `WEBMIN_ROOT_PASSWORD`: password for webmin root user at initialization
+ `WEBMIN_ROOT_HOSTNAME`: hostname for containing docker container
+ `WEBMIN_ROOT_PORT_PREFIX`: port prefix for webmin root user (if it `244` then the port will be `2440`)
+  `PLATFORM`: must be `linux/amd64` or `linux/arm64`

