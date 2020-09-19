#!/usr/bin/env bash

set -o errexit
#set -o nounset
#set -o xtrace

# Expected inputs
# $1: Packer lxc output directory with rootfs and config template
# $2: Name of the new container
output="$1"
name="$2"

if [[ $# -eq 0 ]]; then
  cat <<EOF
  This script deploys templates built with the lxc builder for Packer:
  https://www.packer.io/docs/builders/lxc.html

  No arguments supplied, required args:
   PACKER_OUTPUT_DIR: Packer lxc output directory with rootfs and config template
   CONTAINER_NAME: Name of the new container

  Usage: deploy-output.sh PACKER_OUTPUT_DIR CONTAINER_NAME

  Copy lxc template from PACKER_OUTPUT_DIR to /var/lib/lxc/CONTAINER_NAME
EOF
  exit 1
elif [[ -z "$1" ]]; then
  echo "No packer lxc output dir specified"
  exit 1
elif [[ -z "$2" ]]; then
  echo "No packer lxc output dir specified"
  exit 1
fi


# Prepare lxc config directory
target_config="/srv/lxc/$name/config"
mkdir -p "/srv/lxc/$name"

# Extract the rootfs tarball and add the config
tar -xvf "$output/rootfs.tar.gz" -C "/srv/lxc/$name"

# copy config
cp "$output/lxc-config" $target_config

# adjust rootfs path
echo -e "\nlxc.rootfs.path = dir:/srv/lxc/$name/rootfs" >> $target_config

# set hostname
echo "${name}.local" > "/srv/lxc/$name/rootfs/etc/hostname"
sed -i "s/LXC_NAME/${name}.local/g" "/srv/lxc/$name/rootfs/etc/hosts"
