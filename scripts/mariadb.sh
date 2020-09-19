#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

# install mariadb server and tools
apt-get install -y mariadb-server mariadb-backup

# MySql cecure install

# remove anonymous user
mysql -e "DELETE FROM mysql.user WHERE User='';"

# disallow remote access
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

# drop test database
mysql -e "DROP DATABASE IF EXISTS test;"

# set root password and reload privileges
mysql -e "UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE User='root'; FLUSH PRIVILEGES;"

# configure .my.cnf for root
cat << EOF > /root/.my.cnf
[client]
user = root
password = $MYSQL_ROOT_PASSWORD
EOF

# add additional users
users=($MYSQL_ADDITIONAL_USERS)
hosts=($MYSQL_ADDITIONAL_HOSTS)
passwords=($MYSQL_ADDITIONAL_PASSWORDS)
no_users="${#users[@]}"
for ((i = 0 ; i < $no_users ; i++)); do
  mysql -e "CREATE USER '${users[$i]}'@'${hosts[$i]}' IDENTIFIED BY '${passwords[$i]}';"
done;

# bind
#IP_ETH0=$(ip route | grep eth0 | grep src | awk '{print $9}')
#HOSTNAME=LXCNAME works as well, but refers to the container that was built last (nslookup LXCNAME)
sed -i "s/\(bind.*\) 127.0.0.1/\1 $MYSQL_BIND/g" /etc/mysql/mariadb.conf.d/50-server.cnf
