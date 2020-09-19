#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

# install haproxy
apt-get install -y haproxy socat rsyslog

CHROOT=/var/lib/haproxy

# haproxy log to syslog for haproxy < v1.9
# https://www.haproxy.com/blog/introduction-to-haproxy-logging
mkdir -p "$CHROOT/dev/"
touch "$CHROOT/dev/log"
mount --bind /dev/log "$CHROOT/dev/log"
echo "/dev/log /var/lib/haproxy/dev/log none bind" >> /etc/fstab

cat <<'EOF' > /etc/rsyslog.d/49-haproxy.conf
# Create an additional socket in haproxy's chroot in order to allow logging via
# /dev/log to chroot'ed HAProxy processes
$AddUnixListenSocket /var/lib/haproxy/dev/log
EOF

cat <<EOF > /etc/haproxy/haproxy.cfg
global
#                # log to rsyslog udp
#    log         127.0.0.1 local0
#                # log to stdout/stderr (in effect, journald) for haproxy >= v1.9
#                # https://www.haproxy.com/blog/introduction-to-haproxy-logging
#    log         stderr format short local0 debug
    log         /dev/log  local0
    maxconn     20000
    user        haproxy
    chroot      ${CHROOT}
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

frontend httpfront
    bind                 :80
    mode                 http
    option               httplog
                         # display host header in logs
    capture              request header Host len 30

                         # http acls

    acl                  is_nextcloud hdr(Host) -i nextcloud.com
    use_backend          nextcloud_http if is_nextcloud

                         # redirect to https
                         # (disable https redirection to renew certificates)
#    redirect scheme      https if !{ ssl_fc } is_nextcloud

# SSL passthrough,
# SNI-based virtual hosting
frontend httpsfront
    bind                 :443
    mode                 tcp
    option               tcplog
                         # time to wait for client hello,
                         # maximum time for analysis by HAProxy in next line
    tcp-request          inspect-delay 5s
                         # analyze layer 7 protocol and accept if TLS
    tcp-request          content accept if { req.ssl_hello_type 1 }
                         # name-based virtual hosts
    use_backend          nextcloud if { req.ssl_sni -i nextcloud.com }

#    default_backend      noserv

backend nextcloud_http
    mode                 http
    server               client nextcloud.lan:80
backend nextcloud
    mode                 tcp
    server               client nextcloud.lan:443
EOF
