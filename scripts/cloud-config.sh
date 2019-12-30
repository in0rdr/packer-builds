#!/usr/bin/env bash

set -o errexit
set -o nounset
#set -o xtrace

# install cloud-init
yum install -y cloud-init cloud-utils-growpart

# disable cloud-init
#touch /etc/cloud/cloud-init.disabled
# reset cloud-init
#rm -rf /var/lib/cloud

# change cloud-init default user
sed -i \
  -e 's/name: cloud-user/name: centos/' \
  /etc/cloud/cloud.cfg

# resolve fqdn/hostname to public address
sed -i \
  -e 's/127.0.0.1 {{fqdn}} {{hostname}}/#127.0.0.1 {{fqdn}} {{hostname}}/' \
  -e 's/::1 {{fqdn}} {{hostname}}/#::1 {{fqdn}} {{hostname}}/' \
  /etc/cloud/templates/hosts.redhat.tmpl
