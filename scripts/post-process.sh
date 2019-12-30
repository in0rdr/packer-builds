#!/usr/bin/env bash

set -o errexit
set -o nounset
#set -o xtrace

# https://pve.proxmox.com/wiki/Proxmox_VE_API
# https://pve.proxmox.com/wiki/Cloud-Init_Support#_preparing_cloud_init_templates

yum install -y epel-release jq curl

# read vm id from latest build
vmid=$(jq -r '.builds | sort_by(.build_time) | reverse | .[0].artifact_id' "$PACKER_MANIFEST")

# pve api authorization
ticket=$(curl -s -d "username=$PM_USER&password=$PM_PASS" "$PM_API_URL/access/ticket")
cookie=$(echo "$ticket" | jq -r ".data.ticket" | sed "s/^/PVEAuthCookie=/")
csrftoken=$(echo "$ticket" | jq -r '.data.CSRFPreventionToken' | sed 's/^/CSRFPreventionToken:/')

# add cloud-init drive
curl -s -H "$csrftoken" -XPOST -b "$cookie" \
 "$PM_API_URL/nodes/$PM_NODE/qemu/$vmid/config" \
 --data-urlencode cdrom="local-lvm:cloudinit"

#
# show cloud-init drive
#curl -s -XGET -b "$cookie" \
# "$PM_API_URL/nodes/$PM_NODE/qemu/$vmid/config" | jq '.data.cdrom'
#
# delete cloud-init drive
#curl -s -H "$csrftoken" -XPOST -b "$cookie" \
# "$PM_API_URL/nodes/$PM_NODE/qemu/$vmid/config" \
# --data-urlencode delete="cdrom"
