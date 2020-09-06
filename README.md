# packer-builds

For lxc on Turris, create a symbolic link:
```bash
ln -s /srv/lxc/ /var/lib/lxc
```
(yep, it's [hardcoded](https://github.com/hashicorp/packer/blob/master/builder/lxc/step_lxc_create.go#L22))

## Build

For instance, to build the MariaDB image on Turris with debug logs:
```bash
root@turris:~/packer-builds# PACKER_LOG=1 packer build mariadb-lxc.json
```

## Container from Template Tarball

http://syed.github.io/post/2015-5-6-LXC-tarball-create/

Installing the template:
```bash
curl -L https://raw.githubusercontent.com/in0rdr/salt/fix/lxc/salt/templates/lxc/salt_tarball -o /usr/share/lxc/templates/lxc-tarball
chmod +x /usr/share/lxc/templates/lxc-tarball
```

Using the template - make sure that the config file is named "config":
```bash
mv output-mariadb/{lxc-config,config}
```

Create the container from the template using a default brideg interface:
```bash
root@turris:~/packer-builds# lxc-create -n mariadb -t tarball -- --network_link br-lan --imgtar output-mariadb/rootfs.tar.gz
```