#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

# symlink the proper timezone file,
# https://wiki.debian.org/TimeZoneChanges
ln -fs /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# reconfigure tzdata package to udpate /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata
cat /etc/timezone
