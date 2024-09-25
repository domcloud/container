# DOM Cloud Container

Set up your own DOM Cloud server instance and control it with our platform.

This is a packer script. You need to install [Hashicorp Packer](https://developer.hashicorp.com/packer/docs/install)

To run the final image using QEMU Windows:

```bash
qemu-system-x86_64 -hda domcloud.qcow2 -smp 2 -m 2048 -net nic -net user,hostfwd=tcp::22-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::2443-:2443 -cpu max -accel tcg
```
