#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

# install mariadb server and tools
apt install -y mariadb-server mariadb-backup

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
for u in $MYSQL_ADDITIONAL_USERS; do
  echo $u;
done;
for u in $MYSQL_ADDITIONAL_USERS; do
  echo $u;
done;
