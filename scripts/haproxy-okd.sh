#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

# install haproxy
echo 'debian' | sudo -S apt-get install -y haproxy socat rsyslog

CHROOT=/var/lib/haproxy

# haproxy log to syslog for haproxy < v1.9
# https://www.haproxy.com/blog/introduction-to-haproxy-logging
sudo mkdir -p "$CHROOT/dev/"
sudo touch "$CHROOT/dev/log"
sudo mount --bind /dev/log "$CHROOT/dev/log" 
echo "/dev/log /var/lib/haproxy/dev/log none bind" | sudo -S tee -a /etc/fstab

sudo tee /etc/rsyslog.d/49-haproxy.conf <<'EOF'
# Create an additional socket in haproxy's chroot in order to allow logging via
# /dev/log to chroot'ed HAProxy processes
$AddUnixListenSocket /var/lib/haproxy/dev/log
EOF

sudo tee /etc/haproxy/haproxy.cfg <<EOF
global
#                # log to rsyslog udp
#    log         127.0.0.1 local0
#                # log to stdout/stderr (in effect, journald) for haproxy >= v1.9
#                # https://www.haproxy.com/blog/introduction-to-haproxy-logging
#    log         stderr format short local0 debug
    log         /dev/log  local0
    maxconn     20000
    user        haproxy
    chroot      /var/lib/haproxy
    pidfile     /run/haproxy.pid
    stats       socket /run/haproxy/admin.sock mode 660
    daemon      # Makes the process fork into background.
                # This option is ignored in systemd mode.

defaults
    log                  global
    maxconn              8000
                         # close backend server connections,
                         # but keep-alive client connections
    option               http-server-close
                         # don't try longer than 5s to connect to backend servers
    timeout              connect 5s 
                         # wait 5s for the backend servers to respond,
                         # for instance, until they send headers
    timeout              server 5s
                         # wait 5s for the client to respond
    timeout              client 5s
                         # timeout to use with websockets
                         # overrides, server and client timeout
    timeout              tunnel 2h
                         # remove clients not acknowledging
                         # a server-initiated close after 30s
    timeout              client-fin 30s

listen stats
    bind :9000
    mode http
    stats enable
    stats uri /

frontend kubernetes_api
    bind                 :6443
    default_backend      kubernetes_api_backend
    mode                 tcp
    option               tcplog
backend kubernetes_api_backend
    balance              source
    mode                 tcp
    server               bootstrap okd-bootstrap:6443 check check-ssl verify none
    server               master-01 okd-master-01:6443 check check-ssl verify none
    server               master-02 okd-master-02:6443 check check-ssl verify none
    server               master-03 okd-master-03:6443 check check-ssl verify none

frontend machine_config_server
    bind                 :22623
    default_backend      machine_config_server_backend
    mode                 tcp
    option               tcplog
backend machine_config_server_backend
    balance              source
    mode                 tcp
    server               bootstrap okd-bootstrap:22623 check check-ssl verify none
    server               master-01 okd-master-01:22623 check check-ssl verify none
    server               master-02 okd-master-02:22623 check check-ssl verify none
    server               master-03 okd-master-03:22623 check check-ssl verify none

frontend http_ingress
    bind                 :80
    default_backend      http_ingress_backend 
    mode                 tcp
    option               tcplog
backend http_ingress_backend
    balance              source
    mode                 tcp
                         # use worker/compute nodes, if you have any
    server               master-01 okd-master-01:80 check
    server               master-02 okd-master-02:80 check
    server               master-03 okd-master-03:80 check

frontend https_ingress
    bind                 :443
    default_backend      http_ingress_backend 
    mode                 tcp
    option               tcplog
backend https_ingress_backend
    balance              source
    mode                 tcp
                         # use worker/compute nodes, if you have any
    server               master-01 okd-master-01:443 check check-ssl verify none
    server               master-02 okd-master-02:443 check check-ssl verify none
    server               master-03 okd-master-03:443 check check-ssl verify none
EOF
