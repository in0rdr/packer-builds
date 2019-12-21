#!/usr/bin/env bash

set -o errexit
set -o nounset
#set -o xtrace

# install cloud-init
yum install -y cloud-init cloud-utils-growpart

# change cloud-init defaults
sed -i \
	-e 's/name: cloud-user/name: centos/' \
	/etc/cloud/cloud.cfg
#sed -i \
#	-e 's/127.0.0.1 {{fqdn}}/#127.0.0.1 {{fqdn}}/' \
#       -e '/disable_vmware_customization: false/a manage_etc_hosts: false' \
#	/etc/cloud/templates/hosts.redhat.tmpl
