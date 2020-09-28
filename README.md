# packer-builds

This repo contains some snippets to build containers with Packer.

The notes in this Readme do not follow a particular structure, but should help using the scripts.

## Build Instructions

For instance, to build the MariaDB image with debug logs:
```bash
$ PACKER_LOG=1 packer build mariadb-lxc.json
```

### Suggested Build Order

The following sequence of builds allows you to spin up a small Nextcloud installation.

**1 Build Mariadb**

```
PACKER_LOG=1 packer build \
 -var 'mysql_root_password=123' \
 -var 'mysql_additional_passwords="456"' \
 mariadb-nextcloud.json

./deploy-output.sh output-packer-mariadb-nextcloud mariadb
```

**2 Build Haproxy**

```
PACKER_LOG=1 packer build haproxy-lxc.json
./deploy-output.sh output-packer-haproxy haproxy
```

**3 Nextcloud**

First, start the previously built components:
```bash
lxc-start haproxy
lxc-start mariadb
```

Afterwards, build the Nextcloud container:
```bash
# install nextcloud with the correct database password from step (1)
PACKER_LOG=1 packer build \
 -var 'nextcloud_admin_user=admin' \
 -var 'nextcloud_admin_pass=abc' \
 -var 'nextcloud_database_pass=456' \
 -var 'certbot_mail=root@dev.mail' \
 -var 'overwrite_cli_url=nextcloud.com' \
 nextcloud-lxc.json

./deploy-output.sh output-packer-nextcloud nextcloud
```

## Manual Container Install to LXC Directory

Prepare container name and target config file variables:
```bash
name="container_name"
target_config="/srv/lxc/$name/config"
mkdir "/srv/lxc/$name"
```

Extract the rootfs tarball and add the config:
```bash
# exctract root fs
tar -xvf output-lxc/rootfs.tar.gz -C "/srv/lxc/$name"

# copy config
cp output-lxc/lxc-config $target_config

# adjust rootfs path
echo -e "\nlxc.rootfs.path = dir:/srv/lxc/$name/rootfs" >> $target_config
```

The script `deploy-output.sh` automates the above steps. Usage:
```
$ ./deploy-output.sh
  This script deploys templates built with the lxc builder for Packer:
  https://www.packer.io/docs/builders/lxc.html
  
  No arguments supplied, required args:
   PACKER_OUTPUT_DIR: Packer lxc output directory with rootfs and config template
   CONTAINER_NAME: Name of the new container
  
  Usage: deploy-output.sh PACKER_OUTPUT_DIR CONTAINER_NAME
  
  Copy lxc template from PACKER_OUTPUT_DIR to /var/lib/lxc/CONTAINER_NAME
```

## Haproxy stats
```bash
echo "show stat" | socat stdio /run/haproxy/admin.sock
```

## Isssues
### Issue: Missing LXC Library Dir

```
Build 'lxc' errored: Error creating container: Command error: touch: /var/lib/lxc/packer-lxc/rootfs/tmp/.tmpfs: No such file or directory
```

For lxc on Turris, create a symbolic link:
```bash
ln -s /srv/lxc/ /var/lib/lxc
```
(yep, it's [hardcoded](https://github.com/hashicorp/packer/blob/master/builder/lxc/step_lxc_create.go#L22))


### Issue: Script not Found
```bash
chmod: cannot access '/tmp/script_9801.sh': No such file or directory
/bin/sh: 1: /tmp/script_9801.sh: not found         
```

Fix: Retry, most likely a timing bug on repeated builds


### Issue: Duplicate Nexctloud User
```
Username is invalid because files already exist for this user
```

Fix: Choose another Nextcloud admin user name
```bash
$ PACKER_LOG=1 packer build -var 'nextcloud_admin_user=admin2' -var 'nextcloud_admin_pass=admin2' nextcloud-lxc.json 
```
